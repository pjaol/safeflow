/**
 * Market Research Analysis Script
 * Task 1: Resolve developer origin for top 50 apps
 * Task 2: Privacy policy deep analysis for top 25 apps with websites
 */

const https = require('https');
const http = require('http');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const DATA_PATH = path.join(__dirname, 'results.json');
const ORIGIN_OUTPUT = path.join(__dirname, 'origin_analysis.json');
const PRIVACY_OUTPUT = path.join(__dirname, 'privacy_deep.json');

// ─────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function fetchUrl(url, timeoutMs = 15000) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const lib = parsed.protocol === 'https:' ? https : http;
    const options = {
      hostname: parsed.hostname,
      port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
      path: parsed.pathname + parsed.search,
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      },
      timeout: timeoutMs,
    };
    const req = lib.request(options, (res) => {
      // Follow redirects (up to 5)
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
        const redirectUrl = res.headers.location.startsWith('http')
          ? res.headers.location
          : `${parsed.protocol}//${parsed.hostname}${res.headers.location}`;
        return fetchUrl(redirectUrl, timeoutMs).then(resolve).catch(reject);
      }
      let data = '';
      res.setEncoding('utf8');
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => resolve({ status: res.statusCode, body: data, url }));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Request timed out')); });
    req.end();
  });
}

async function fetchWithFallback(url, timeoutMs = 15000) {
  try {
    return await fetchUrl(url, timeoutMs);
  } catch (e) {
    return null;
  }
}

// ─────────────────────────────────────────────────
// TASK 1: ORIGIN RESOLUTION
// ─────────────────────────────────────────────────

const COMPANY_SUFFIX_MAP = {
  'gmbh': 'Germany',
  'ag': 'Germany/Switzerland',
  'ug': 'Germany',
  'kg': 'Germany',
  'ohg': 'Germany',
  'gbr': 'Germany',
  's.r.l.': 'Italy',
  'srl': 'Italy',
  's.p.a.': 'Italy',
  'spa': 'Italy',
  'sarl': 'France',
  'sas': 'France',
  's.a.s.': 'France',
  'sa': 'France/Spain/Belgium',
  'ab': 'Sweden',
  'oy': 'Finland',
  'oyj': 'Finland',
  'as': 'Norway/Estonia',
  'bv': 'Netherlands',
  'nv': 'Netherlands/Belgium',
  'ltd': 'UK/HK',
  'limited': 'UK/HK',
  'plc': 'UK',
  'llp': 'UK/US',
  'pty': 'Australia',
  'pty ltd': 'Australia',
  'pty. ltd.': 'Australia',
  'inc': 'USA',
  'inc.': 'USA',
  'llc': 'USA',
  'corp': 'USA',
  'corporation': 'USA',
  'lp': 'USA',
  'pvt': 'India',
  'pvt ltd': 'India',
  'pvt. ltd.': 'India',
  'kk': 'Japan',
  'k.k.': 'Japan',
  'ivs': 'Denmark',
  'aps': 'Denmark',
  'a/s': 'Denmark',
};

const TLD_COUNTRY_MAP = {
  '.de': 'Germany',
  '.at': 'Austria',
  '.ch': 'Switzerland',
  '.ru': 'Russia',
  '.cn': 'China',
  '.jp': 'Japan',
  '.fr': 'France',
  '.it': 'Italy',
  '.es': 'Spain',
  '.se': 'Sweden',
  '.no': 'Norway',
  '.fi': 'Finland',
  '.dk': 'Denmark',
  '.nl': 'Netherlands',
  '.be': 'Belgium',
  '.pl': 'Poland',
  '.cz': 'Czech Republic',
  '.hu': 'Hungary',
  '.ro': 'Romania',
  '.ua': 'Ukraine',
  '.br': 'Brazil',
  '.mx': 'Mexico',
  '.ar': 'Argentina',
  '.in': 'India',
  '.kr': 'South Korea',
  '.au': 'Australia',
  '.nz': 'New Zealand',
  '.ca': 'Canada',
  '.sg': 'Singapore',
  '.hk': 'Hong Kong',
  '.tw': 'Taiwan',
  '.id': 'Indonesia',
  '.tr': 'Turkey',
  '.il': 'Israel',
  '.za': 'South Africa',
  '.ie': 'Ireland',
  '.pt': 'Portugal',
  '.gr': 'Greece',
  '.sk': 'Slovakia',
  '.bg': 'Bulgaria',
  '.hr': 'Croatia',
  '.ee': 'Estonia',
  '.lv': 'Latvia',
  '.lt': 'Lithuania',
};

function hasCyrillicChars(str) {
  return /[\u0400-\u04FF]/.test(str);
}

function hasChineseChars(str) {
  return /[\u4E00-\u9FFF\u3400-\u4DBF]/.test(str);
}

function hasJapaneseChars(str) {
  return /[\u3040-\u309F\u30A0-\u30FF]/.test(str);
}

function hasKoreanChars(str) {
  return /[\uAC00-\uD7AF\u1100-\u11FF]/.test(str);
}

function resolveTldCountry(websiteUrl) {
  if (!websiteUrl) return null;
  try {
    const url = new URL(websiteUrl);
    const hostname = url.hostname.toLowerCase();
    // Check two-part TLDs first (.co.uk, .com.au)
    for (const tld of Object.keys(TLD_COUNTRY_MAP)) {
      if (hostname.endsWith(tld)) {
        return { country: TLD_COUNTRY_MAP[tld], method: `TLD (${tld})` };
      }
    }
  } catch {}
  return null;
}

function resolveDevNameCountry(developerName, developerWebsite) {
  if (!developerName) return null;
  const name = developerName.toLowerCase();

  // Check unicode chars
  if (hasCyrillicChars(developerName)) return { country: 'Russia', method: 'Cyrillic chars in developer name' };
  if (hasChineseChars(developerName)) return { country: 'China', method: 'Chinese chars in developer name' };
  if (hasJapaneseChars(developerName)) return { country: 'Japan', method: 'Japanese chars in developer name' };
  if (hasKoreanChars(developerName)) return { country: 'South Korea', method: 'Korean chars in developer name' };

  // Check company suffixes (longest match first)
  const sortedSuffixes = Object.keys(COMPANY_SUFFIX_MAP).sort((a, b) => b.length - a.length);
  for (const suffix of sortedSuffixes) {
    // Match suffix at end of string or followed by punctuation/space
    const regex = new RegExp(`\\b${suffix.replace('.', '\\.')}\\b`, 'i');
    if (regex.test(name)) {
      return { country: COMPANY_SUFFIX_MAP[suffix], method: `Company suffix (${suffix})` };
    }
  }

  // Check website URL for country-specific patterns
  if (developerWebsite) {
    const site = developerWebsite.toLowerCase();
    if (site.includes('china') || site.includes('.cn')) return { country: 'China', method: 'Website contains .cn' };
    if (site.includes('hangzhou') || site.includes('beijing') || site.includes('shanghai')) return { country: 'China', method: 'Chinese city in URL' };
    if (site.includes('nordic') || site.includes('sweden')) return { country: 'Sweden', method: 'Nordic keyword' };
  }

  // Check developer name for geographic keywords
  if (/(hangzhou|beijing|shanghai|shenzhen|chengdu|guangzhou)/i.test(name)) return { country: 'China', method: 'Chinese city in developer name' };
  if (/(nordic|stockholm|sweden|swedish)/i.test(name)) return { country: 'Sweden', method: 'Swedish keyword in developer name' };
  if (/(london|england|british|uk)/i.test(name)) return { country: 'UK', method: 'UK keyword in developer name' };
  if (/(berlin|munich|hamburg|german)/i.test(name)) return { country: 'Germany', method: 'German keyword in developer name' };
  if (/(new york|san francisco|california|boston|chicago|seattle|austin|denver)/i.test(name)) return { country: 'USA', method: 'US city in developer name' };
  if (/(israel|tel aviv)/i.test(name)) return { country: 'Israel', method: 'Israeli keyword' };
  if (/(australia|sydney|melbourne)/i.test(name)) return { country: 'Australia', method: 'Australian keyword' };
  if (/(canada|toronto|vancouver|montreal)/i.test(name)) return { country: 'Canada', method: 'Canadian keyword' };

  return null;
}

function runWhois(domain, timeoutMs = 8000) {
  try {
    const result = execSync(`whois ${domain}`, { timeout: timeoutMs, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
    return result;
  } catch (e) {
    return null;
  }
}

function parseWhoisCountry(whoisText) {
  if (!whoisText) return null;
  const lines = whoisText.split('\n');
  const countryPatterns = [
    /^country:\s*(.+)/im,
    /^registrant country:\s*(.+)/im,
    /^registrant-country:\s*(.+)/im,
    /^org-country:\s*(.+)/im,
    /country-code:\s*(.+)/im,
  ];
  for (const pattern of countryPatterns) {
    for (const line of lines) {
      const m = line.match(pattern);
      if (m) {
        const code = m[1].trim().toUpperCase();
        return code;
      }
    }
  }
  return null;
}

const ISO_TO_COUNTRY = {
  'US': 'USA', 'GB': 'UK', 'DE': 'Germany', 'FR': 'France', 'IT': 'Italy',
  'ES': 'Spain', 'NL': 'Netherlands', 'SE': 'Sweden', 'NO': 'Norway',
  'FI': 'Finland', 'DK': 'Denmark', 'CH': 'Switzerland', 'AT': 'Austria',
  'BE': 'Belgium', 'PL': 'Poland', 'RU': 'Russia', 'CN': 'China',
  'JP': 'Japan', 'KR': 'South Korea', 'AU': 'Australia', 'NZ': 'New Zealand',
  'CA': 'Canada', 'IN': 'India', 'BR': 'Brazil', 'MX': 'Mexico',
  'SG': 'Singapore', 'HK': 'Hong Kong', 'TW': 'Taiwan', 'IL': 'Israel',
  'ZA': 'South Africa', 'IE': 'Ireland', 'PT': 'Portugal', 'CZ': 'Czech Republic',
  'HU': 'Hungary', 'RO': 'Romania', 'UA': 'Ukraine', 'EE': 'Estonia',
  'LV': 'Latvia', 'LT': 'Lithuania', 'SK': 'Slovakia', 'BG': 'Bulgaria',
  'HR': 'Croatia', 'UA': 'Ukraine', 'AR': 'Argentina', 'TR': 'Turkey',
  'ID': 'Indonesia', 'UA': 'Ukraine',
};

async function resolveOrigin(app) {
  const { developer, developerWebsite } = app;
  const result = {
    appId: app.appId,
    title: app.title,
    developer,
    developerWebsite,
    reviews: app.reviews,
    country: 'Unknown',
    confidence: 'low',
    method: 'none',
  };

  // 1. Check developer name / unicode chars / company suffixes
  const nameResult = resolveDevNameCountry(developer, developerWebsite);
  if (nameResult) {
    result.country = nameResult.country;
    result.confidence = 'medium';
    result.method = nameResult.method;
  }

  // 2. TLD analysis (may override if high confidence)
  if (!developerWebsite) {
    return result;
  }

  const tldResult = resolveTldCountry(developerWebsite);
  if (tldResult) {
    result.country = tldResult.country;
    result.confidence = 'high';
    result.method = tldResult.method;
    return result;
  }

  // 3. WHOIS lookup if we still don't know
  if (result.country === 'Unknown' || result.confidence === 'low') {
    try {
      const domain = new URL(developerWebsite).hostname.replace(/^www\./, '');
      process.stdout.write(`  WHOIS ${domain}... `);
      const whoisText = runWhois(domain);
      const countryCode = parseWhoisCountry(whoisText);
      if (countryCode && ISO_TO_COUNTRY[countryCode]) {
        result.country = ISO_TO_COUNTRY[countryCode];
        result.confidence = 'high';
        result.method = `WHOIS country code (${countryCode})`;
        process.stdout.write(`${result.country}\n`);
      } else if (countryCode) {
        result.country = countryCode;
        result.confidence = 'medium';
        result.method = `WHOIS country code (raw: ${countryCode})`;
        process.stdout.write(`${result.country}\n`);
      } else {
        process.stdout.write(`no match\n`);
      }
    } catch (e) {
      process.stdout.write(`error\n`);
    }
  }

  return result;
}

// ─────────────────────────────────────────────────
// TASK 2: PRIVACY POLICY ANALYSIS
// ─────────────────────────────────────────────────

const PRIVACY_URL_PATHS = ['/privacy', '/privacy-policy', '/legal/privacy', '/privacy-statement', '/policies/privacy', '/en/privacy', '/en/privacy-policy'];

async function findPrivacyPolicyUrl(baseUrl, knownPrivacyUrl) {
  if (knownPrivacyUrl) {
    return knownPrivacyUrl;
  }

  // Try common paths
  const normalizedBase = baseUrl.replace(/\/$/, '');
  for (const p of PRIVACY_URL_PATHS) {
    const testUrl = normalizedBase + p;
    try {
      const resp = await fetchWithFallback(testUrl, 10000);
      if (resp && resp.status === 200 && resp.body.length > 500) {
        // Make sure it actually looks like a privacy policy
        const bodyLower = resp.body.toLowerCase();
        if (bodyLower.includes('privacy') || bodyLower.includes('personal data') || bodyLower.includes('data protection')) {
          return testUrl;
        }
      }
    } catch {}
    await sleep(200);
  }

  // Try fetching the homepage and looking for privacy link
  try {
    const homeResp = await fetchWithFallback(normalizedBase, 10000);
    if (homeResp && homeResp.body) {
      const bodyLower = homeResp.body.toLowerCase();
      // Find privacy links in the HTML
      const privacyLinkRegex = /href=["']([^"']*(?:privacy|datenschutz|confidentialite)[^"']*)["']/gi;
      let match;
      while ((match = privacyLinkRegex.exec(homeResp.body)) !== null) {
        let link = match[1];
        if (link.startsWith('/')) {
          const parsed = new URL(normalizedBase);
          link = `${parsed.protocol}//${parsed.hostname}${link}`;
        } else if (!link.startsWith('http')) {
          link = `${normalizedBase}/${link}`;
        }
        return link;
      }
    }
  } catch {}

  return null;
}

function analyzePrivacyText(text, url) {
  const body = text.toLowerCase();
  const analysis = {
    collectsHealthData: false,
    collectsMenstrualData: false,
    sharesWithThirdParties: false,
    sellsData: false,
    hasAdvertising: false,
    cloudSyncRequired: null,
    canUseWithoutAccount: null,
    governingLaw: [],
    gdpr: false,
    ccpa: false,
    notes: [],
  };

  // Health / menstrual data collection
  if (/menstrual|period|cycle|ovulation|fertility|pregnancy|reproductive/.test(body)) {
    analysis.collectsMenstrualData = true;
  }
  if (/health (data|information|profile)|medical data|personal health|sensitive (data|information)/.test(body)) {
    analysis.collectsHealthData = true;
  }

  // Third party sharing
  if (/third.party|third party|service provider|partner[s]? (may|can|will)|share.*(data|information)/.test(body)) {
    analysis.sharesWithThirdParties = true;
  }

  // Data selling
  if (/sell.*(your|personal|user).*(data|information)|do not sell|we (never |don't |do not )sell|sale of (personal|your) (data|information)/.test(body)) {
    if (/do not sell|we never sell|we don't sell|we do not sell/.test(body)) {
      analysis.sellsData = false;
      analysis.notes.push('Explicitly states data is not sold');
    } else {
      analysis.sellsData = true;
    }
  }

  // Advertising
  if (/advertis|ad network|google ads|facebook ads|marketing partner|targeted ad/.test(body)) {
    analysis.hasAdvertising = true;
  }

  // Account required / cloud sync
  if (/without an account|no account required|account is not required/.test(body)) {
    analysis.canUseWithoutAccount = true;
  } else if (/must (create|register|sign up)|account is required|require.*account/.test(body)) {
    analysis.canUseWithoutAccount = false;
  }

  if (/sync.*cloud|cloud.*sync|backup.*server|server.*backup|cloud storage/.test(body)) {
    if (/optional.*sync|sync.*optional|you can choose|without sync/.test(body)) {
      analysis.cloudSyncRequired = false;
    } else {
      analysis.cloudSyncRequired = true;
    }
  }

  // Governing law
  if (/gdpr|general data protection regulation|european union|eu resident/.test(body)) {
    analysis.gdpr = true;
    analysis.governingLaw.push('GDPR (EU)');
  }
  if (/ccpa|california consumer privacy|california resident/.test(body)) {
    analysis.ccpa = true;
    analysis.governingLaw.push('CCPA (California)');
  }
  if (/england and wales|laws of england|united kingdom law|uk law/.test(body)) {
    analysis.governingLaw.push('UK Law');
  }
  if (/governed by.*laws of (delaware|new york|california|state of|the state)/.test(body)) {
    const match = body.match(/laws of (delaware|new york|california|state of \w+|the state of \w+)/);
    if (match) analysis.governingLaw.push(`US - ${match[1]}`);
  }
  if (/german law|laws of germany/.test(body)) analysis.governingLaw.push('German Law');
  if (/swedish law|laws of sweden/.test(body)) analysis.governingLaw.push('Swedish Law');
  if (/pipeda|canadian (privacy|law)/.test(body)) analysis.governingLaw.push('PIPEDA (Canada)');
  if (/pdpa|personal data protection act/.test(body)) analysis.governingLaw.push('PDPA');

  return analysis;
}

async function analyzePrivacyPolicy(app) {
  const result = {
    appId: app.appId,
    title: app.title,
    developer: app.developer,
    developerWebsite: app.developerWebsite,
    reviews: app.reviews,
    privacyPolicyUrl: null,
    fetchStatus: 'not_attempted',
    analysis: null,
    rawTextLength: 0,
    error: null,
  };

  console.log(`\n  Analyzing privacy: ${app.title}`);
  console.log(`  Website: ${app.developerWebsite}`);

  try {
    const privacyUrl = await findPrivacyPolicyUrl(app.developerWebsite, app.privacyPolicyUrl);
    if (!privacyUrl) {
      result.fetchStatus = 'not_found';
      result.error = 'Could not find privacy policy URL';
      console.log(`  Status: Not found`);
      return result;
    }

    result.privacyPolicyUrl = privacyUrl;
    console.log(`  Privacy URL: ${privacyUrl}`);

    const resp = await fetchWithFallback(privacyUrl, 20000);
    if (!resp || resp.status !== 200) {
      result.fetchStatus = resp ? `http_${resp.status}` : 'fetch_failed';
      result.error = `HTTP ${resp ? resp.status : 'error'}`;
      console.log(`  Status: ${result.fetchStatus}`);
      return result;
    }

    result.fetchStatus = 'success';
    result.rawTextLength = resp.body.length;

    // Strip HTML tags for text analysis
    const cleanText = resp.body
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, ' ')
      .replace(/<[^>]+>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    result.analysis = analyzePrivacyText(cleanText, privacyUrl);
    console.log(`  Collected? menstrual=${result.analysis.collectsMenstrualData}, health=${result.analysis.collectsHealthData}`);
    console.log(`  Third parties=${result.analysis.sharesWithThirdParties}, sells=${result.analysis.sellsData}`);
    console.log(`  Law: ${result.analysis.governingLaw.join(', ') || 'not detected'}`);

  } catch (e) {
    result.fetchStatus = 'error';
    result.error = e.message;
    console.log(`  Error: ${e.message}`);
  }

  return result;
}

// ─────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────

async function main() {
  const allApps = JSON.parse(fs.readFileSync(DATA_PATH, 'utf8'));
  const sorted = [...allApps].sort((a, b) => b.reviews - a.reviews);

  console.log(`\n${'='.repeat(60)}`);
  console.log('TASK 1: ORIGIN RESOLUTION (Top 50 apps)');
  console.log('='.repeat(60));

  const top50 = sorted.slice(0, 50);
  const originResults = [];

  for (let i = 0; i < top50.length; i++) {
    const app = top50[i];
    process.stdout.write(`[${i + 1}/50] ${app.title.substring(0, 40).padEnd(40)} `);
    const origin = await resolveOrigin(app);
    originResults.push(origin);
    console.log(`→ ${origin.country} (${origin.confidence}) [${origin.method}]`);
    await sleep(500); // Rate limit WHOIS
  }

  // Also process remaining apps with name/TLD analysis only (no WHOIS)
  console.log('\nProcessing remaining apps (name/TLD analysis only)...');
  const remainingOrigins = [];
  for (const app of sorted.slice(50)) {
    const nameResult = resolveDevNameCountry(app.developer, app.developerWebsite);
    const tldResult = app.developerWebsite ? resolveTldCountry(app.developerWebsite) : null;
    const country = tldResult ? tldResult.country : (nameResult ? nameResult.country : 'Unknown');
    const method = tldResult ? tldResult.method : (nameResult ? nameResult.method : 'none');
    const confidence = tldResult ? 'high' : (nameResult ? 'medium' : 'low');
    remainingOrigins.push({
      appId: app.appId,
      title: app.title,
      developer: app.developer,
      developerWebsite: app.developerWebsite,
      reviews: app.reviews,
      country,
      confidence,
      method,
    });
  }

  const allOrigins = [...originResults, ...remainingOrigins];
  fs.writeFileSync(ORIGIN_OUTPUT, JSON.stringify(allOrigins, null, 2));
  console.log(`\nOrigin analysis written to ${ORIGIN_OUTPUT}`);

  // ─────────────────────────────────────────────────
  console.log(`\n${'='.repeat(60)}`);
  console.log('TASK 2: PRIVACY POLICY DEEP ANALYSIS (Top 25 with websites)');
  console.log('='.repeat(60));

  // Get top 25 that have a developerWebsite
  const top25WithSites = sorted.filter(a => a.developerWebsite).slice(0, 25);
  console.log(`Analyzing ${top25WithSites.length} apps with websites...`);

  const privacyResults = [];
  for (const app of top25WithSites) {
    const privacyResult = await analyzePrivacyPolicy(app);
    privacyResults.push(privacyResult);
    await sleep(1000); // Be polite
  }

  fs.writeFileSync(PRIVACY_OUTPUT, JSON.stringify(privacyResults, null, 2));
  console.log(`\nPrivacy analysis written to ${PRIVACY_OUTPUT}`);

  // ─────────────────────────────────────────────────
  // SUMMARY REPORT
  // ─────────────────────────────────────────────────

  console.log(`\n${'='.repeat(60)}`);
  console.log('SUMMARY REPORT');
  console.log('='.repeat(60));

  // Origin breakdown
  const countryCounts = {};
  for (const a of allOrigins) {
    const c = a.country;
    countryCounts[c] = (countryCounts[c] || 0) + 1;
  }
  const sortedCountries = Object.entries(countryCounts).sort((a, b) => b[1] - a[1]);

  console.log('\n--- Developer Country of Origin (all 289 apps) ---');
  for (const [country, count] of sortedCountries) {
    const pct = ((count / allApps.length) * 100).toFixed(1);
    console.log(`  ${country.padEnd(30)} ${String(count).padStart(3)}  (${pct}%)`);
  }

  // Review-weighted origin for top 50
  console.log('\n--- Top 50 Apps by Review Count: Origin ---');
  for (const a of originResults) {
    console.log(`  ${String(a.reviews).padStart(8)}  ${a.title.substring(0, 35).padEnd(35)}  ${a.country}`);
  }

  // Privacy summary
  console.log('\n--- Privacy Policy Analysis Summary ---');
  const successful = privacyResults.filter(r => r.fetchStatus === 'success' && r.analysis);
  console.log(`\nFetched successfully: ${successful.length}/${privacyResults.length}`);

  const metrics = {
    collectsMenstrual: successful.filter(r => r.analysis.collectsMenstrualData).length,
    collectsHealth: successful.filter(r => r.analysis.collectsHealthData).length,
    sharesThirdParty: successful.filter(r => r.analysis.sharesWithThirdParties).length,
    sellsData: successful.filter(r => r.analysis.sellsData === true).length,
    noSellData: successful.filter(r => r.analysis.sellsData === false).length,
    hasAds: successful.filter(r => r.analysis.hasAdvertising).length,
    gdpr: successful.filter(r => r.analysis.gdpr).length,
    ccpa: successful.filter(r => r.analysis.ccpa).length,
  };

  console.log(`\n  Mentions menstrual/cycle data:     ${metrics.collectsMenstrual}/${successful.length}`);
  console.log(`  Mentions health data collection:   ${metrics.collectsHealth}/${successful.length}`);
  console.log(`  Shares with third parties:         ${metrics.sharesThirdParty}/${successful.length}`);
  console.log(`  Explicitly sells data:             ${metrics.sellsData}/${successful.length}`);
  console.log(`  Explicitly states no data selling: ${metrics.noSellData}/${successful.length}`);
  console.log(`  Has advertising:                   ${metrics.hasAds}/${successful.length}`);
  console.log(`  GDPR compliant:                    ${metrics.gdpr}/${successful.length}`);
  console.log(`  CCPA compliant:                    ${metrics.ccpa}/${successful.length}`);

  console.log('\n--- Per-App Privacy Details ---');
  for (const r of privacyResults) {
    const a = r.analysis;
    console.log(`\n  ${r.title}`);
    console.log(`    Status: ${r.fetchStatus}`);
    if (a) {
      console.log(`    Collects menstrual data: ${a.collectsMenstrualData}`);
      console.log(`    Collects health data:    ${a.collectsHealthData}`);
      console.log(`    Shares w/ 3rd parties:  ${a.sharesWithThirdParties}`);
      console.log(`    Sells data:              ${a.sellsData}`);
      console.log(`    Has advertising:         ${a.hasAdvertising}`);
      console.log(`    GDPR: ${a.gdpr}  CCPA: ${a.ccpa}`);
      console.log(`    Governing law:           ${a.governingLaw.join(', ') || 'not detected'}`);
      if (a.notes.length) console.log(`    Notes:                   ${a.notes.join('; ')}`);
    }
  }

  console.log(`\n${'='.repeat(60)}`);
  console.log('Analysis complete.');
  console.log(`Output files:`);
  console.log(`  ${ORIGIN_OUTPUT}`);
  console.log(`  ${PRIVACY_OUTPUT}`);
  console.log('='.repeat(60));
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
