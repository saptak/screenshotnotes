#!/usr/bin/env ruby

require 'xcodeproj'

# Open the Xcode project
project_path = 'ScreenshotNotes.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'ScreenshotNotes' }

if target.nil?
  puts "❌ Could not find ScreenshotNotes target"
  exit 1
end

puts "✅ Found target: #{target.name}"

# Get the main group
main_group = project.main_group

# Find or create ScreenshotNotes group
screenshots_group = main_group.children.find { |child| child.display_name == 'ScreenshotNotes' }
if screenshots_group.nil?
  screenshots_group = main_group.new_group('ScreenshotNotes')
  puts "✅ Created ScreenshotNotes group"
else
  puts "✅ Found ScreenshotNotes group"
end

# List of Swift files to add
swift_files = [
  # Core app files
  'ScreenshotNotesApp.swift',
  'ContentView.swift', 
  'ScreenshotDetailView.swift',
  'ImageStorageService.swift',
  
  # Models
  'Models/Screenshot.swift',
  'Models/SearchQuery.swift',
  'Models/EntityExtraction.swift',
  
  # ViewModels
  'ViewModels/ScreenshotListViewModel.swift',
  
  # Services
  'Services/HapticService.swift',
  'Services/PhotoLibraryService.swift',
  'Services/BackgroundTaskService.swift',
  'Services/SettingsService.swift',
  'Services/OCRService.swift',
  'Services/SearchService.swift',
  'Services/SearchCache.swift',
  'Services/BackgroundOCRProcessor.swift',
  'Services/MaterialDesignSystem.swift',
  'Services/MaterialPerformanceTest.swift',
  'Services/MaterialVisualTest.swift',
  'Services/HeroAnimationService.swift',
  'Services/HeroAnimationEdgeCaseHandler.swift',
  'Services/HeroAnimationPerformanceTester.swift',
  'Services/HeroAnimationVisualValidator.swift',
  'Services/HapticFeedbackService.swift',
  'Services/ContextualMenuService.swift',
  'Services/QuickActionService.swift',
  'Services/ContextualMenuAccessibilityService.swift',
  'Services/ContextualMenuPerformanceTester.swift',
  'Services/EnhancedPullToRefreshService.swift',
  'Services/AdvancedSwipeGestureService.swift',
  'Services/MultiTouchGestureService.swift',
  'Services/GesturePerformanceTester.swift',
  'Services/GestureAccessibilityService.swift',
  'Services/GestureStateManager.swift',
  
  # AI Services
  'Services/AI/SimpleQueryParser.swift',
  'Services/AI/EntityExtractionService.swift',
  'Services/AI/EntityExtractionIntegrationTests.swift',
  'Services/AI/EntityExtractionDemo.swift',
  
  # Views
  'Views/SettingsView.swift',
  'Views/PermissionsView.swift',
  'Views/SearchView.swift',
  'Views/SearchFiltersView.swift'
]

added_count = 0
skipped_count = 0

swift_files.each do |file_path|
  full_path = File.join(Dir.pwd, file_path)
  
  # Check if file exists
  unless File.exist?(full_path)
    puts "⚠️  File not found: #{file_path}"
    skipped_count += 1
    next
  end
  
  # Check if file is already in project
  existing_file = project.files.find { |f| f.path == file_path }
  if existing_file
    puts "⚠️  File already in project: #{file_path}"
    skipped_count += 1
    next
  end
  
  # Add file to project
  begin
    # Create groups if needed
    dir_components = File.dirname(file_path).split('/')
    current_group = screenshots_group
    
    dir_components.each do |component|
      next if component == '.'
      
      child_group = current_group.children.find { |child| child.display_name == component }
      if child_group.nil?
        child_group = current_group.new_group(component)
        puts "✅ Created group: #{component}"
      end
      current_group = child_group
    end
    
    # Add file to the appropriate group
    file_ref = current_group.new_file(full_path)
    target.add_file_references([file_ref])
    
    puts "✅ Added file: #{file_path}"
    added_count += 1
    
  rescue => e
    puts "❌ Error adding file #{file_path}: #{e.message}"
    skipped_count += 1
  end
end

# Save the project
project.save

puts "\n📊 Summary:"
puts "✅ Added: #{added_count} files"
puts "⚠️  Skipped: #{skipped_count} files"
puts "💾 Project saved successfully!"

if added_count > 0
  puts "\n🚀 Next steps:"
  puts "1. Clean and rebuild the project:"
  puts "   xcodebuild clean build -project ScreenshotNotes.xcodeproj -scheme ScreenshotNotes -destination 'platform=iOS Simulator,name=iPhone 16'"
  puts "2. The app should now have an executable and run in the simulator!"
end
