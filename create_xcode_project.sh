#!/bin/bash
# Create a minimal iOS Xcode project structure

PROJECT_DIR="/Users/paveld/LavenderMessenger-ios/LavenderMessenger.xcodeproj"
mkdir -p "$PROJECT_DIR"

# Create project.pbxproj
cat > "$PROJECT_DIR/project.pbxproj" << 'PBXPROJ'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	rootObject = /* Project object */;

	/* Begin PBXProject section */
	/* End PBXProject section */
}
PBXPROJ

echo "Created $PROJECT_DIR"
