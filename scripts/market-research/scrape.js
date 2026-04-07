const store = require('app-store-scraper');
const fs = require('fs');

const SEARCH_TERMS = [
  'menstrual cycle tracker',
  'period tracker',
  'period tracking',
  'menstrual calendar',
  'ovulation tracker',
  'fertility tracker',
  'cycle tracking women',
];

// Key markets
const COUNTRIES = ['us', 'gb', 'de', 'fr', 'in', 'br', 'au', 'ca', 'ru', 'cn', 'jp', 'kr'];

// Keywords that indicate a result is NOT a menstrual/cycle tracker
const NOISE_KEYWORDS = [
  'sleep', 'bike', 'cycling', 'bicycle', 'snore', 'outdoor', 'hiking',
  'run', 'training', 'pokemon', 'carb', 'speedometer', 'gps route',
  'samsung health', 'google maps', 'citymapper', 'tfl', 'transit',
  'keto', 'weight', 'calorie', 'workout', 'fitness tracker',
  'blood pressure', 'glucose', 'diabetes', 'heart rate monitor',
];

function isRelevant(app) {
  const text = (app.title + ' ' + (app.description || '') + ' ' + app.primaryGenre).toLowerCase();
  // Must be in Health & Fitness or Medical
  if (!['Health & Fitness', 'Medical', 'Lifestyle'].includes(app.primaryGenre)) return false;
  // Must contain a relevant keyword
  const relevant = ['period', 'menstrual', 'cycle', 'ovulat', 'fertilit', 'pregnan', 'womens health', "women's health"];
  if (!relevant.some(kw => text.includes(kw))) return false;
  // Must NOT be primarily about something else
  const titleLower = app.title.toLowerCase();
  if (NOISE_KEYWORDS.some(kw => titleLower.includes(kw))) return false;
  return true;
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function main() {
  console.log('=== App Store Market Research: Menstrual Cycle Trackers ===\n');

  // Phase 1: collect unique apps
  const seen = new Map(); // numericId -> app

  for (const term of SEARCH_TERMS) {
    for (const country of COUNTRIES) {
      process.stdout.write(`Searching "${term}" [${country}]... `);
      try {
        const results = await store.search({ term, country, num: 50, lang: 'en-us' });
        const relevant = results.filter(isRelevant);
        let newCount = 0;
        for (const app of relevant) {
          // Extract numeric ID from URL: .../id1234567890
          const match = (app.url || '').match(/\/id(\d+)/);
          const numId = match ? parseInt(match[1]) : null;
          if (numId && !seen.has(numId)) {
            seen.set(numId, { ...app, numericId: numId });
            newCount++;
          }
        }
        console.log(`${results.length} results → ${relevant.length} relevant, ${newCount} new (total: ${seen.size})`);
      } catch (e) {
        console.log(`ERROR: ${e.message}`);
      }
      await sleep(300);
    }
  }

  console.log(`\n${seen.size} unique relevant apps found. Fetching full details...\n`);

  // Phase 2: get full details using numeric ID
  const apps = [];
  let i = 0;
  for (const [numId, basic] of seen) {
    i++;
    process.stdout.write(`[${i}/${seen.size}] ${basic.title.substring(0, 40).padEnd(40)} `);
    try {
      const detail = await store.app({ id: numId, country: 'us', ratings: true });
      apps.push({ ...detail, numericId: numId });
      const pricing = detail.free
        ? (detail.inAppPurchases ? 'Free+IAP' : 'Free')
        : `$${detail.price}`;
      console.log(`| ${pricing.padEnd(10)} | ★${(detail.score || 0).toFixed(1)} | ${(detail.reviews || 0).toLocaleString()} reviews`);
    } catch (e) {
      // Try GB store as fallback
      try {
        const detail = await store.app({ id: numId, country: 'gb', ratings: true });
        apps.push({ ...detail, numericId: numId, _fallbackCountry: 'gb' });
        console.log(`(gb fallback) | ★${(detail.score || 0).toFixed(1)}`);
      } catch (e2) {
        apps.push({ ...basic, numericId: numId, _detailFailed: true });
        console.log(`(search data only)`);
      }
    }
    await sleep(250);
  }

  // Phase 3: structure
  const structured = apps.map(app => {
    // Determine pricing category
    let pricingCategory;
    if (!app.free) {
      pricingCategory = 'paid';
    } else if (app.inAppPurchases) {
      pricingCategory = 'freemium';
    } else {
      pricingCategory = 'free';
    }

    // Heuristic: is this likely on-device only?
    const desc = (app.description || '').toLowerCase();
    const onDeviceSignals = ['no account', 'offline', 'no cloud', 'no server', 'on.device', 'on device', 'no data', 'local storage', 'no sign', 'no login', 'no registration'];
    const cloudSignals = ['sync', 'cloud', 'account', 'sign in', 'log in', 'backup', 'server'];
    const likelyOnDevice = onDeviceSignals.some(s => desc.includes(s)) && !cloudSignals.some(s => desc.includes(s));

    return {
      numericId: app.numericId,
      appId: app.appId,
      title: app.title,
      developer: app.developer,
      developerWebsite: app.developerWebsite || null,
      primaryGenre: app.primaryGenre,
      price: app.price,
      free: app.free,
      inAppPurchases: app.inAppPurchases || false,
      pricingCategory,
      score: app.score ? parseFloat(app.score.toFixed(2)) : null,
      reviews: app.reviews || 0,
      ratings: app.ratings || 0,
      version: app.version,
      released: app.released,
      updated: app.updated,
      sizeMB: app.size ? (parseInt(app.size) / 1048576).toFixed(1) : null,
      privacyPolicyUrl: app.privacyPolicyUrl || null,
      url: app.url,
      descriptionSnippet: app.description ? app.description.substring(0, 300) : null,
      likelyOnDevice,
      _detailFailed: app._detailFailed || false,
    };
  });

  // Sort by reviews desc
  structured.sort((a, b) => (b.reviews || 0) - (a.reviews || 0));

  fs.writeFileSync('results.json', JSON.stringify(structured, null, 2));
  console.log(`\nSaved ${structured.length} apps to results.json`);

  // ── ANALYSIS ──
  const total = structured.length;
  console.log('\n' + '='.repeat(60));
  console.log('ANALYSIS SUMMARY');
  console.log('='.repeat(60));
  console.log(`\nTotal unique cycle-tracking apps found: ${total}`);

  // Pricing
  const free = structured.filter(a => a.pricingCategory === 'free').length;
  const freemium = structured.filter(a => a.pricingCategory === 'freemium').length;
  const paid = structured.filter(a => a.pricingCategory === 'paid').length;
  console.log(`\nPricing distribution:`);
  console.log(`  Free (no IAP):     ${free.toString().padStart(3)} (${pct(free, total)}%)`);
  console.log(`  Freemium (IAP):    ${freemium.toString().padStart(3)} (${pct(freemium, total)}%)`);
  console.log(`  Paid upfront:      ${paid.toString().padStart(3)} (${pct(paid, total)}%)`);

  // Privacy policy
  const hasPrivacy = structured.filter(a => a.privacyPolicyUrl).length;
  console.log(`\nHave a privacy policy URL: ${hasPrivacy}/${total} (${pct(hasPrivacy, total)}%)`);

  // On-device heuristic
  const onDevice = structured.filter(a => a.likelyOnDevice);
  console.log(`\nLikely on-device only (heuristic): ${onDevice.length}`);
  if (onDevice.length > 0) {
    for (const a of onDevice) console.log(`  • ${a.title} (${a.developer})`);
  }

  // Top 25 by reviews
  console.log(`\nTop 25 by review count:`);
  const header = 'App'.padEnd(38) + 'Developer'.padEnd(32) + 'Pricing'.padEnd(12) + 'Score'.padEnd(8) + 'Reviews';
  console.log(header);
  console.log('-'.repeat(header.length));
  for (const app of structured.slice(0, 25)) {
    const pricing = app.free ? (app.inAppPurchases ? 'Free+IAP' : 'Free') : `$${app.price}`;
    console.log(
      app.title.substring(0, 37).padEnd(38) +
      app.developer.substring(0, 31).padEnd(32) +
      pricing.padEnd(12) +
      `★${(app.score || 0).toFixed(1)}`.padEnd(8) +
      (app.reviews || 0).toLocaleString()
    );
  }

  // Developer origin analysis
  console.log(`\nDeveloper origins (from website domain / name heuristics):`);
  const origins = {};
  for (const app of structured) {
    const origin = guessOrigin(app);
    origins[origin] = (origins[origin] || 0) + 1;
  }
  for (const [country, count] of Object.entries(origins).sort((a, b) => b[1] - a[1])) {
    console.log(`  ${country.padEnd(20)} ${count} apps`);
  }

  // CSV
  const csvRows = [
    'numericId,title,developer,pricingCategory,price,inAppPurchases,score,reviews,privacyPolicyUrl,released,updated,developerWebsite,likelyOnDevice'
  ];
  for (const app of structured) {
    csvRows.push([
      app.numericId,
      `"${(app.title || '').replace(/"/g, '""')}"`,
      `"${(app.developer || '').replace(/"/g, '""')}"`,
      app.pricingCategory,
      app.price,
      app.inAppPurchases,
      app.score,
      app.reviews,
      `"${app.privacyPolicyUrl || ''}"`,
      app.released ? app.released.split('T')[0] : '',
      app.updated ? app.updated.split('T')[0] : '',
      `"${app.developerWebsite || ''}"`,
      app.likelyOnDevice,
    ].join(','));
  }
  fs.writeFileSync('results.csv', csvRows.join('\n'));
  console.log(`\nSaved results.csv`);
}

function guessOrigin(app) {
  const dev = (app.developer || '').toLowerCase();
  const web = (app.developerWebsite || '').toLowerCase();
  const combined = dev + ' ' + web;

  if (web.includes('.cn') || web.includes('.com.cn') || combined.includes('hangzhou') || combined.includes('beijing') || combined.includes('shanghai') || combined.includes('shenzhen')) return 'China';
  if (web.includes('.de') || combined.includes('gmbh') || combined.includes('berlin') || combined.includes('munich')) return 'Germany';
  if (web.includes('.ru') || combined.includes('russian') || combined.includes('moscow')) return 'Russia';
  if (web.includes('.jp') || combined.includes('japan') || combined.includes('tokyo')) return 'Japan';
  if (web.includes('.kr') || combined.includes('korea') || combined.includes('seoul')) return 'South Korea';
  if (web.includes('.in') || combined.includes('india') || combined.includes('bangalore') || combined.includes('mumbai')) return 'India';
  if (web.includes('.br') || combined.includes('brasil') || combined.includes('brazil')) return 'Brazil';
  if (web.includes('.fr') || combined.includes('france') || combined.includes('paris')) return 'France';
  if (web.includes('.uk') || web.includes('.co.uk') || combined.includes('united kingdom') || combined.includes(' uk ') || combined.includes('london')) return 'UK';
  if (web.includes('.au') || combined.includes('australia') || combined.includes('sydney') || combined.includes('melbourne')) return 'Australia';
  if (combined.includes('llc') || combined.includes('inc') || combined.includes('corp') || web.includes('.com')) return 'US (likely)';
  return 'Unknown';
}

function pct(n, total) {
  return total ? ((n / total) * 100).toFixed(1) : '0.0';
}

main().catch(console.error);
