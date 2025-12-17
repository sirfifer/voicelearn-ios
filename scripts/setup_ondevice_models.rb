#!/usr/bin/env ruby
# Script to add on-device GLM-ASR models to Xcode project
# Run from project root: ruby scripts/setup_ondevice_models.rb

require 'xcodeproj'

PROJECT_PATH = 'VoiceLearn.xcodeproj'
TARGET_NAME = 'VoiceLearn'

# Model files to add to Copy Bundle Resources
MODEL_FILES = [
  'models/glm-asr-nano/GLMASRWhisperEncoder.mlpackage',
  'models/glm-asr-nano/GLMASRAudioAdapter.mlpackage',
  'models/glm-asr-nano/GLMASREmbedHead.mlpackage',
  'models/glm-asr-nano/GLMASRConvEncoder.mlpackage',
  'models/glm-asr-nano/glm-asr-nano-q4km.gguf'
]

# Source files to add
SOURCE_FILES = [
  'VoiceLearn/Services/STT/GLMASROnDeviceSTTService.swift'
]

def main
  puts "Opening Xcode project..."
  project = Xcodeproj::Project.open(PROJECT_PATH)
  target = project.targets.find { |t| t.name == TARGET_NAME }

  unless target
    puts "Error: Target '#{TARGET_NAME}' not found"
    exit 1
  end

  main_group = project.main_group

  # Add LLAMA_AVAILABLE to Swift compiler flags
  puts "\nAdding LLAMA_AVAILABLE compiler flag..."
  target.build_configurations.each do |config|
    flags = config.build_settings['OTHER_SWIFT_FLAGS'] || '$(inherited)'
    unless flags.include?('LLAMA_AVAILABLE')
      flags = "#{flags} -DLLAMA_AVAILABLE"
      config.build_settings['OTHER_SWIFT_FLAGS'] = flags
      puts "  Added to #{config.name}"
    end
  end

  # Find or create Models group
  models_group = main_group.groups.find { |g| g.name == 'Models' }
  unless models_group
    models_group = main_group.new_group('Models')
    puts "\nCreated 'Models' group"
  end

  # Add model files to Copy Bundle Resources
  puts "\nAdding model files to Copy Bundle Resources..."
  resources_phase = target.resources_build_phase

  MODEL_FILES.each do |model_path|
    next unless File.exist?(model_path)

    filename = File.basename(model_path)

    # Check if already added
    existing = models_group.files.find { |f| f.name == filename || f.path == model_path }
    if existing
      puts "  #{filename} already in project"
      next
    end

    # Add file reference
    file_ref = models_group.new_reference(model_path)
    file_ref.name = filename

    # Add to resources phase
    unless resources_phase.files.any? { |f| f.file_ref&.path == model_path }
      resources_phase.add_file_reference(file_ref)
      puts "  Added #{filename}"
    end
  end

  # Add source files
  puts "\nAdding source files..."
  SOURCE_FILES.each do |source_path|
    next unless File.exist?(source_path)

    filename = File.basename(source_path)

    # Find STT group
    stt_group = find_group(main_group, 'Services/STT') || find_group(main_group, 'STT')
    unless stt_group
      puts "  Warning: Could not find STT group, adding to main group"
      stt_group = main_group
    end

    # Check if already added
    existing = stt_group.files.find { |f| f.name == filename }
    if existing
      puts "  #{filename} already in project"
      next
    end

    # Add file reference
    file_ref = stt_group.new_reference(source_path)
    file_ref.name = filename

    # Add to sources phase
    target.source_build_phase.add_file_reference(file_ref)
    puts "  Added #{filename}"
  end

  # Save project
  puts "\nSaving project..."
  project.save
  puts "Done!"
end

def find_group(parent, path)
  parts = path.split('/')
  current = parent

  parts.each do |part|
    found = current.groups.find { |g| g.name == part || g.path == part }
    return nil unless found
    current = found
  end

  current
end

main
