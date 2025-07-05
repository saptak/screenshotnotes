#!/usr/bin/env ruby

require 'xcodeproj'

# Open the Xcode project
project_path = 'ScreenshotNotes.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'ScreenshotNotes' }

# Find all Swift files in the current directory and subdirectories
swift_files = Dir.glob('**/*.swift').reject { |f| f.include?('Test') }

puts "Found Swift files:"
swift_files.each { |f| puts "  #{f}" }

# Add each Swift file to the project
swift_files.each do |file_path|
  # Skip if file is already in project
  existing_file = project.main_group.find_subpath(file_path)
  next if existing_file

  # Add file to project
  file_ref = project.main_group.new_reference(file_path)
  
  # Add to target's source build phase
  target.source_build_phase.add_file_reference(file_ref)
  
  puts "Added: #{file_path}"
end

# Save the project
project.save

puts "\nProject updated! All Swift files added to ScreenshotNotes target."
puts "Now run: xcodebuild clean build -project ScreenshotNotes.xcodeproj -scheme ScreenshotNotes -destination 'platform=iOS Simulator,name=iPhone 16'"
