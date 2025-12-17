#!/usr/bin/env python3
"""
Add GLMASROnDeviceSTTService.swift and model files to Xcode project.
"""

import os
import re
import random
import string

PROJECT_FILE = "VoiceLearn.xcodeproj/project.pbxproj"

def generate_uuid():
    """Generate a 24-character hex UUID like Xcode uses."""
    chars = string.hexdigits.upper()[:16]
    return ''.join(random.choice(chars) for _ in range(24))

def read_project():
    with open(PROJECT_FILE, 'r') as f:
        return f.read()

def write_project(content):
    with open(PROJECT_FILE, 'w') as f:
        f.write(content)

def add_source_file(content, filename, path):
    """Add a Swift source file to the project."""

    # Check if already exists
    if filename in content:
        print(f"  {filename} already in project")
        return content

    # Generate UUIDs
    file_ref_uuid = generate_uuid()
    build_file_uuid = generate_uuid()

    # Add PBXFileReference
    file_ref_entry = f'\t\t{file_ref_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n'

    # Find where to insert (after last PBXFileReference)
    pattern = r'(/\* End PBXFileReference section \*/)'
    content = re.sub(pattern, f'{file_ref_entry}{chr(10)}/* End PBXFileReference section */', content)

    # Add PBXBuildFile
    build_file_entry = f'\t\t{build_file_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {filename} */; }};\n'

    pattern = r'(/\* End PBXBuildFile section \*/)'
    content = re.sub(pattern, f'{build_file_entry}/* End PBXBuildFile section */', content)

    # Add to STT group (find the STT group's children list)
    # Find the line with GLMASRSTTService.swift and add after it
    pattern = r'(E8536D559854F89B9630C6F2 /\* GLMASRSTTService\.swift \*/,)'
    replacement = f'\\1\n\t\t\t\t{file_ref_uuid} /* {filename} */,'
    content = re.sub(pattern, replacement, content)

    # Add to Sources build phase (find where GLMASRSTTService.swift is in sources)
    pattern = r'(4EF17C8315F0F06267492967 /\* GLMASRSTTService\.swift in Sources \*/,)'
    replacement = f'\\1\n\t\t\t\t{build_file_uuid} /* {filename} in Sources */,'
    content = re.sub(pattern, replacement, content)

    print(f"  Added {filename}")
    return content

def add_resource_folder(content, folder_name, folder_path):
    """Add a folder reference (for .mlpackage) to Copy Bundle Resources."""

    if folder_name in content:
        print(f"  {folder_name} already in project")
        return content

    file_ref_uuid = generate_uuid()
    build_file_uuid = generate_uuid()

    # Determine file type
    if folder_name.endswith('.mlpackage'):
        file_type = 'folder'
    elif folder_name.endswith('.gguf'):
        file_type = 'file'
    else:
        file_type = 'folder'

    # Add PBXFileReference
    if file_type == 'folder':
        file_ref_entry = f'\t\t{file_ref_uuid} /* {folder_name} */ = {{isa = PBXFileReference; lastKnownFileType = folder; path = "{folder_path}"; sourceTree = SOURCE_ROOT; }};\n'
    else:
        file_ref_entry = f'\t\t{file_ref_uuid} /* {folder_name} */ = {{isa = PBXFileReference; lastKnownFileType = file; path = "{folder_path}"; sourceTree = SOURCE_ROOT; }};\n'

    pattern = r'(/\* End PBXFileReference section \*/)'
    content = re.sub(pattern, f'{file_ref_entry}{chr(10)}/* End PBXFileReference section */', content)

    # Add PBXBuildFile for Resources
    build_file_entry = f'\t\t{build_file_uuid} /* {folder_name} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {folder_name} */; }};\n'

    pattern = r'(/\* End PBXBuildFile section \*/)'
    content = re.sub(pattern, f'{build_file_entry}/* End PBXBuildFile section */', content)

    # Add to Resources build phase - find the Resources phase and add to files list
    # Look for PBXResourcesBuildPhase and add to its files array
    # Find a pattern like: files = ( followed by entries
    resources_pattern = r'(isa = PBXResourcesBuildPhase;[^}]*files = \(\s*\n)'
    def add_to_resources(match):
        return f'{match.group(1)}\t\t\t\t{build_file_uuid} /* {folder_name} in Resources */,\n'
    content = re.sub(resources_pattern, add_to_resources, content, count=1)

    # Add to main group children
    # Find the VoiceLearn group and add the reference
    # This is trickier - let's add it to the root project group
    main_group_pattern = r'(mainGroup = [A-F0-9]{24}[^;]*;)'

    print(f"  Added {folder_name}")
    return content

def main():
    if not os.path.exists(PROJECT_FILE):
        print(f"Error: {PROJECT_FILE} not found. Run from project root.")
        return

    print("Reading Xcode project...")
    content = read_project()

    # Add GLMASROnDeviceSTTService.swift
    print("\nAdding source files:")
    content = add_source_file(
        content,
        "GLMASROnDeviceSTTService.swift",
        "VoiceLearn/Services/STT/GLMASROnDeviceSTTService.swift"
    )

    # Add model files
    print("\nAdding model files:")
    models = [
        ("GLMASRWhisperEncoder.mlpackage", "models/glm-asr-nano/GLMASRWhisperEncoder.mlpackage"),
        ("GLMASRAudioAdapter.mlpackage", "models/glm-asr-nano/GLMASRAudioAdapter.mlpackage"),
        ("GLMASREmbedHead.mlpackage", "models/glm-asr-nano/GLMASREmbedHead.mlpackage"),
        ("GLMASRConvEncoder.mlpackage", "models/glm-asr-nano/GLMASRConvEncoder.mlpackage"),
        ("glm-asr-nano-q4km.gguf", "models/glm-asr-nano/glm-asr-nano-q4km.gguf"),
    ]

    for name, path in models:
        if os.path.exists(path):
            content = add_resource_folder(content, name, path)
        else:
            print(f"  WARNING: {path} not found")

    print("\nSaving project...")
    write_project(content)
    print("Done!")

if __name__ == "__main__":
    main()
