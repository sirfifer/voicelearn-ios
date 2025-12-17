#!/usr/bin/env python3
"""
Script to add files to Xcode project.
Modifies project.pbxproj to include GLMASROnDeviceSTTService.swift and model files.
"""

import os
import re
import uuid
import sys

PROJECT_FILE = "VoiceLearn.xcodeproj/project.pbxproj"

def generate_uuid():
    """Generate a 24-character hex UUID like Xcode uses."""
    return uuid.uuid4().hex[:24].upper()

def read_project():
    with open(PROJECT_FILE, 'r') as f:
        return f.read()

def write_project(content):
    with open(PROJECT_FILE, 'w') as f:
        f.write(content)

def find_stt_group_id(content):
    """Find the STT group's UUID in the project."""
    # Look for STT group reference
    match = re.search(r'([A-F0-9]{24})\s*/\*\s*STT\s*\*/', content)
    if match:
        return match.group(1)
    return None

def find_main_target_id(content):
    """Find the VoiceLearn target UUID."""
    match = re.search(r'([A-F0-9]{24})\s*/\*\s*VoiceLearn\s*\*/\s*=\s*\{[^}]*isa\s*=\s*PBXNativeTarget', content)
    if match:
        return match.group(1)
    return None

def find_sources_build_phase(content):
    """Find the Sources build phase UUID for VoiceLearn target."""
    # Look for PBXSourcesBuildPhase
    match = re.search(r'([A-F0-9]{24})\s*/\*\s*Sources\s*\*/\s*=\s*\{[^}]*isa\s*=\s*PBXSourcesBuildPhase', content)
    if match:
        return match.group(1)
    return None

def find_resources_build_phase(content):
    """Find the Resources build phase UUID for VoiceLearn target."""
    match = re.search(r'([A-F0-9]{24})\s*/\*\s*Resources\s*\*/\s*=\s*\{[^}]*isa\s*=\s*PBXResourcesBuildPhase', content)
    if match:
        return match.group(1)
    return None

def check_file_exists(content, filename):
    """Check if a file is already in the project."""
    return filename in content

def add_swift_flags(content):
    """Add LLAMA_AVAILABLE to OTHER_SWIFT_FLAGS."""
    if '-DLLAMA_AVAILABLE' in content:
        print("  LLAMA_AVAILABLE flag already present")
        return content

    # Find OTHER_SWIFT_FLAGS and add our flag
    pattern = r'(OTHER_SWIFT_FLAGS\s*=\s*")([^"]*)"'

    def replace_flags(match):
        existing = match.group(2)
        if '-DLLAMA_AVAILABLE' not in existing:
            return f'{match.group(1)}{existing} -DLLAMA_AVAILABLE"'
        return match.group(0)

    new_content = re.sub(pattern, replace_flags, content)

    # If no existing OTHER_SWIFT_FLAGS, add it to build settings
    if new_content == content:
        # Add to Debug and Release configurations
        pattern = r'(buildSettings\s*=\s*\{[^}]*)(};)'
        def add_flag(match):
            settings = match.group(1)
            if 'OTHER_SWIFT_FLAGS' not in settings:
                return f'{settings}\t\t\t\tOTHER_SWIFT_FLAGS = "-DLLAMA_AVAILABLE";\n\t\t\t{match.group(2)}'
            return match.group(0)
        new_content = re.sub(pattern, add_flag, new_content)

    print("  Added LLAMA_AVAILABLE flag")
    return new_content

def main():
    if not os.path.exists(PROJECT_FILE):
        print(f"Error: {PROJECT_FILE} not found")
        sys.exit(1)

    print("Reading Xcode project...")
    content = read_project()
    original_content = content

    # Check what's already there
    print("\nChecking existing files:")
    if check_file_exists(content, "GLMASROnDeviceSTTService.swift"):
        print("  GLMASROnDeviceSTTService.swift - already in project")
    else:
        print("  GLMASROnDeviceSTTService.swift - NOT in project (needs to be added manually)")

    print("\nAdding compiler flag...")
    content = add_swift_flags(content)

    if content != original_content:
        print("\nSaving project...")
        write_project(content)
        print("Done! Changes saved.")
    else:
        print("\nNo changes needed.")

    print("\n" + "="*60)
    print("MANUAL STEPS REQUIRED:")
    print("="*60)
    print("""
1. Open VoiceLearn.xcodeproj in Xcode

2. Add GLMASROnDeviceSTTService.swift:
   - Right-click on VoiceLearn/Services/STT folder
   - Select "Add Files to VoiceLearn..."
   - Navigate to: VoiceLearn/Services/STT/GLMASROnDeviceSTTService.swift
   - Ensure "VoiceLearn" target is checked
   - Click Add

3. Add model files to Copy Bundle Resources:
   - Right-click on VoiceLearn folder (or create a "Models" group)
   - Select "Add Files to VoiceLearn..."
   - Navigate to: models/glm-asr-nano/
   - Select these files:
     * GLMASRWhisperEncoder.mlpackage
     * GLMASRAudioAdapter.mlpackage
     * GLMASREmbedHead.mlpackage
     * GLMASRConvEncoder.mlpackage
     * glm-asr-nano-q4km.gguf
   - Check "Copy items if needed"
   - Ensure "VoiceLearn" target is checked
   - Click Add

4. Verify LLAMA_AVAILABLE flag:
   - Select VoiceLearn target
   - Go to Build Settings
   - Search for "Other Swift Flags"
   - Ensure "-DLLAMA_AVAILABLE" is present

5. Build (Cmd+B) and Run (Cmd+R)
""")

if __name__ == "__main__":
    main()
