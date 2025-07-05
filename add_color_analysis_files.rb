#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'ScreenshotNotes.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'ScreenshotNotes' }

# Find the Services/AI group
services_group = project.main_group.find_subpath('ScreenshotNotes/Services/AI')
if services_group.nil?
  puts "Services/AI group not found!"
  exit 1
end

# Find the Models group
models_group = project.main_group.find_subpath('ScreenshotNotes/Models')
if models_group.nil?
  puts "Models group not found!"
  exit 1
end

# Add ColorAnalysisService.swift to Services/AI
color_analysis_service_path = 'ScreenshotNotes/Services/AI/ColorAnalysisService.swift'
if File.exist?(color_analysis_service_path)
  file_ref = services_group.new_reference(color_analysis_service_path)
  target.add_file_references([file_ref])
  puts "Added ColorAnalysisService.swift to project"
else
  puts "ColorAnalysisService.swift not found at expected path"
end

# Add ColorPalette.swift to Models
color_palette_path = 'ScreenshotNotes/Models/ColorPalette.swift'
if File.exist?(color_palette_path)
  file_ref = models_group.new_reference(color_palette_path)
  target.add_file_references([file_ref])
  puts "Added ColorPalette.swift to project"
else
  puts "ColorPalette.swift not found at expected path"
end

# Save the project
project.save

puts "Project updated successfully!"
