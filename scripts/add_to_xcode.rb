#!/usr/bin/env ruby
# Adds Content pipeline files to the Xcode project.
# Run once after setting up the pipeline:
#   ruby scripts/add_to_xcode.rb

require 'xcodeproj'
require 'pathname'

REPO_ROOT   = Pathname.new(__FILE__).dirname.parent
PROJ_PATH   = REPO_ROOT / "safeflow.xcodeproj"
TARGET_NAME = "safeflow"

proj   = Xcodeproj::Project.open(PROJ_PATH)
target = proj.targets.find { |t| t.name == TARGET_NAME }
abort "Target '#{TARGET_NAME}' not found" unless target

# ── Helper: find or create a group by path components ──────────────────────────
def find_or_create_group(parent, *components)
  components.reduce(parent) do |grp, name|
    grp[name] || grp.new_group(name, name)
  end
end

main_group = proj.main_group

# ── 1. Resources/Content — JSON files (Copy Bundle Resources) ─────────────────
resources_group  = find_or_create_group(main_group, "Resources")
content_group    = find_or_create_group(resources_group, "Content")

json_files = Dir[REPO_ROOT / "Resources/Content/*.json"].sort
copy_phase = target.resources_build_phase

json_files.each do |path|
  filename = File.basename(path)
  next if content_group.files.any? { |f| f.path&.end_with?(filename) }

  file_ref = content_group.new_reference(path)
  file_ref.last_known_file_type = "text.json"

  unless copy_phase.files_references.include?(file_ref)
    copy_phase.add_file_reference(file_ref)
  end
  puts "  Added resource: #{filename}"
end

# ── 2. Sources/Services/Content — Swift files (Compile Sources) ───────────────
services_group = find_or_create_group(main_group, "Sources", "Services", "Content")
swift_files    = Dir[REPO_ROOT / "Sources/Services/Content/*.swift"].sort
sources_phase  = target.source_build_phase

swift_files.each do |path|
  filename = File.basename(path)
  next if services_group.files.any? { |f| f.path&.end_with?(filename) }

  file_ref = services_group.new_reference(path)
  file_ref.last_known_file_type = "sourcecode.swift"

  unless sources_phase.files_references.include?(file_ref)
    sources_phase.add_file_reference(file_ref)
  end
  puts "  Added source:   #{filename}"
end

proj.save
puts "\nProject saved. #{json_files.size} JSON + #{swift_files.size} Swift files processed."
