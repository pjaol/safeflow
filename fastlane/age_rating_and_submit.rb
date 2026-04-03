#!/usr/bin/env ruby
# Sets age rating on the App Store version and submits for review
# Usage: bundle exec ruby fastlane/age_rating_and_submit.rb

require 'spaceship'

APP_ID    = "6761509532"
VERSION   = "1.0"

# Auth via API key (same as Fastfile)
key_id    = ENV["ASC_KEY_ID"]    or abort "Set ASC_KEY_ID"
issuer_id = ENV["ASC_ISSUER_ID"] or abort "Set ASC_ISSUER_ID"
key_path  = ENV["ASC_KEY_PATH"]  or abort "Set ASC_KEY_PATH"

Spaceship::ConnectAPI.auth(
  key_id: key_id,
  issuer_id: issuer_id,
  filepath: key_path
)

client = Spaceship::ConnectAPI

# Find the edit version
puts "Finding v#{VERSION} edit version..."
versions = client::AppStoreVersion.all(
  filter: { app: APP_ID, platform: "IOS", appStoreState: ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "WAITING_FOR_REVIEW"] }
)
version = versions.find { |v| v.version_string == VERSION }
abort "Could not find v#{VERSION} in editable state" unless version
puts "Found version id: #{version.id}"

# Age rating — all NONE / false for a health tracking app with no objectionable content
puts "Setting age rating..."
client.patch_app_store_versions_age_rating_declaration(
  app_store_version_id: version.id,
  attributes: {
    alcoholTobaccoOrDrugUseOrReferences:          "NONE",
    contests:                                      "NONE",
    gambling:                                      false,
    gamblingSimulated:                             "NONE",
    horrorOrFearThemes:                            "NONE",
    matureOrSuggestiveThemes:                      "NONE",
    medicalOrTreatmentInformation:                 "NONE",
    profanityOrCrudeHumor:                         "NONE",
    sexualContentGraphicAndNudity:                 "NONE",
    sexualContentOrNudity:                         "NONE",
    unrestrictedWebAccess:                         false,
    violenceCartoonOrFantasy:                      "NONE",
    violenceRealistic:                             "NONE",
    violenceRealisticProlongedGraphicOrSadistic:   "NONE",
    lootBox:                                       false,
    userGeneratedContent:                          "NONE",
    gunsOrOtherWeapons:                            "NONE",
    parentalControls:                              "NONE",
    healthOrWellnessTopics:                        "NONE",
    ageAssurance:                                  "NONE",
    gambling:                                      false,
  }
)
puts "Age rating set."

# Submit for review
puts "Submitting v#{VERSION} for App Store review..."
submission = client::ReviewSubmission.create(
  app_id: APP_ID,
  platform: "IOS"
)
submission.add_app_store_version_to_review_items(
  app_store_version_id: version.id
)
submission.submit_for_review
puts "Submitted! Apple will review within 24-48 hours."
