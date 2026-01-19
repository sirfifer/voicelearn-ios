#!/usr/bin/env python3
"""
Add missing algorithm files to Xcode project
"""

import re
import uuid
import sys
from pathlib import Path

def generate_uuid():
    """Generate a unique 24-character hex string like Xcode uses"""
    return ''.join([format(x, '02X') for x in uuid.uuid4().bytes[:12]])

def add_file_to_project(project_path, file_path, group_path):
    """Add a Swift file to the Xcode project"""

    with open(project_path, 'r') as f:
        content = f.read()

    file_name = Path(file_path).name
    relative_path = str(Path(file_path).relative_to(Path(project_path).parent.parent))

    # Generate UUIDs for the new file
    file_ref_uuid = generate_uuid()
    build_file_uuid = generate_uuid()

    # Find the PBXFileReference section
    file_ref_section_match = re.search(
        r'(/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/)',
        content,
        re.DOTALL
    )

    if not file_ref_section_match:
        print(f"ERROR: Could not find PBXFileReference section")
        return False

    # Add file reference (use KBSynonymDictionaries.swift as template)
    file_ref_entry = f'\t\t{file_ref_uuid} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_name}; sourceTree = "<group>"; }};\n'

    # Insert before the end comment
    content = content.replace(
        '/* End PBXFileReference section */',
        f'{file_ref_entry}\t/* End PBXFileReference section */'
    )

    # Find the PBXBuildFile section
    build_file_section_match = re.search(
        r'(/\* Begin PBXBuildFile section \*/.*?/\* End PBXBuildFile section \*/)',
        content,
        re.DOTALL
    )

    if not build_file_section_match:
        print(f"ERROR: Could not find PBXBuildFile section")
        return False

    # Add build file entry
    build_file_entry = f'\t\t{build_file_uuid} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {file_name} */; }};\n'

    content = content.replace(
        '/* End PBXBuildFile section */',
        f'{build_file_entry}\t/* End PBXBuildFile section */'
    )

    # Find the Algorithms group (by looking for KBSynonymDictionaries.swift's group or similar pattern)
    # We need to add our file to the children array of the Algorithms group

    # First, let's find a group that contains other algorithm/service files
    group_match = re.search(
        r'([A-Z0-9]{24}) /\* Algorithms \*/ = \{.*?children = \((.*?)\);',
        content,
        re.DOTALL
    )

    if group_match:
        group_uuid = group_match.group(1)
        children = group_match.group(2)

        # Add our file to the children list
        new_child = f'\n\t\t\t\t{file_ref_uuid} /* {file_name} */,'

        # Find the position to insert (before the closing parenthesis)
        content = content.replace(
            f'{group_uuid} /* Algorithms */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = ({children});',
            f'{group_uuid} /* Algorithms */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = ({children}{new_child}\n\t\t\t);',
            1
        )
    else:
        print(f"WARNING: Could not find Algorithms group, file added but not in group")

    # Find the PBXSourcesBuildPhase section and add to it
    sources_phase_match = re.search(
        r'([A-Z0-9]{24}) /\* Sources \*/ = \{.*?files = \((.*?)\);',
        content,
        re.DOTALL
    )

    if sources_phase_match:
        files_section = sources_phase_match.group(2)
        new_source = f'\n\t\t\t\t{build_file_uuid} /* {file_name} in Sources */,'

        content = re.sub(
            r'(files = \([^)]*)',
            r'\1' + new_source,
            content,
            count=1
        )
    else:
        print(f"ERROR: Could not find Sources build phase")
        return False

    # Write the modified content back
    with open(project_path, 'w') as f:
        f.write(content)

    print(f"✓ Added {file_name} to project")
    return True

def main():
    project_path = Path("/Users/ramerman/dev/unamentis/UnaMentis.xcodeproj/project.pbxproj")

    if not project_path.exists():
        print(f"ERROR: Project file not found: {project_path}")
        return 1

    # Files to add
    files_to_add = [
        "UnaMentis/Services/KnowledgeBowl/Algorithms/KBPhoneticMatcher.swift",
        "UnaMentis/Services/KnowledgeBowl/Algorithms/KBNGramMatcher.swift",
        "UnaMentis/Services/KnowledgeBowl/Algorithms/KBTokenMatcher.swift",
        "UnaMentis/Services/KnowledgeBowl/Algorithms/KBLinguisticMatcher.swift",
    ]

    print("Adding missing algorithm files to Xcode project...")
    print()

    for file_path in files_to_add:
        full_path = Path("/Users/ramerman/dev/unamentis") / file_path
        if not full_path.exists():
            print(f"✗ File does not exist: {full_path}")
            continue

        add_file_to_project(project_path, full_path, "Algorithms")

    print()
    print("Done! Files added to Xcode project.")
    print("Note: You may want to verify the project opens correctly in Xcode.")

    return 0

if __name__ == "__main__":
    sys.exit(main())
