#!/bin/bash

VOID_PACKAGES_DIR="$HOME/gits/void-packages"
TEMPLATE_FILE="$VOID_PACKAGES_DIR/srcpkgs/brave-bin/template"
GITHUB_API_URL="https://api.github.com/repos/brave/brave-browser/releases/latest"

# We have to download the entire deb file just to calculate the checksum.
# During build/install this will be downloaded again...
# TODO: Get checksum from releases page ie find name that matches with jq eg:
# "name": "brave-browser_${latest_version}_amd64.deb",
get_new_checksum() {
	# Create temporary directory
	TMP_DIR=$(mktemp -d)
	cd "$TMP_DIR"

	deb_url="https://github.com/brave/brave-browser/releases/download/v${latest_version}/brave-browser_${latest_version}_amd64.deb"
	echo "Downloading to calculate checksum: $deb_url"
	echo ""
	curl -L -o "brave-browser_${latest_version}_amd64.deb" "$deb_url"

	if [ ! -f "brave-browser_${latest_version}_amd64.deb" ]; then
		echo "Error: Failed to download the deb file."
		rm -rf "$TMP_DIR"
		exit 1
	fi

	new_checksum=$(sha256sum "brave-browser_${latest_version}_amd64.deb" | awk '{print $1}')

	if [ -z "$new_checksum" ]; then
		echo "Error: Failed to calculate checksum."
		rm -rf "$TMP_DIR"
		exit 1
	fi

	rm -rf "$TMP_DIR"
	return 0
}

main() {
	# Check dependencies
	for cmd in curl jq ar tar; do
		if ! command -v $cmd &> /dev/null; then
			echo "Error: $cmd is required but not installed."
			exit 1
		fi
	done

	# Fetch latest version number
	latest_version=$(curl -s "$GITHUB_API_URL" |
	jq -r '.tag_name' |
	sed 's/^v//')

	if [ -z "$latest_version" ]; then
		echo "Error: Failed to fetch the latest version."
		exit 1
	fi

	current_version=$(grep -oP 'version=\K[0-9.]+' "$TEMPLATE_FILE")
	current_checksum=$(grep -oP 'checksum=\K[a-f0-9]+' "$TEMPLATE_FILE")

	# Check if update is needed
	if [ "$current_version" = "$latest_version" ]; then
		echo "Brave is already at the latest version ($current_version)."
		echo "Verify it yourself: https://github.com/brave/brave-browser/releases/latest"
		echo ""
		echo "Note: If you never built and installed after updating the template, you will need to do that manually:"
		echo ""
		echo "cd $VOID_PACKAGES_DIR && ./xbps-src pkg brave-bin && sudo xi brave-bin"
		exit 0
	fi

	# Get the new checksum
	get_new_checksum

	echo ""
	echo "Summary of changes:"
	echo "-------------------"
	echo "Version: $current_version -> $latest_version"
	echo "Checksum: $current_checksum -> $new_checksum"
	echo ""
	echo "Verify it yourself: https://github.com/brave/brave-browser/releases/latest"
	echo "How: Ctrl+F with the new checksum: $new_checksum"
	echo ""

	read -p "Do you want to proceed with the update? (y/n): " confirm
	if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
		echo "Update cancelled."
		exit 0
	fi

	sed -i "s/version=[0-9.]\+/version=$latest_version/" "$TEMPLATE_FILE"
	sed -i "s/checksum=[a-f0-9]\+/checksum=$new_checksum/" "$TEMPLATE_FILE"

	echo "Updated template with latest version and checksum"

	read -p "Do you want to build and install the package now? (y/n): " answer
	if [[ "$answer" =~ ^[Yy]$ ]]; then
		echo ""
		echo "Building and installing the package..."
		cd "$VOID_PACKAGES_DIR"

		# Build the package
		./xbps-src pkg brave-bin

		# Install the package
		echo ""
		echo "Password required: sudo xi brave-bin"
		sudo xi brave-bin
	else
		echo "You can build and install the package later with:"
		echo "cd $VOID_PACKAGES_DIR && ./xbps-src pkg brave-bin && sudo xi brave-bin"
		echo ""
		echo "OR without xi:"
		echo ""
		echo "cd $VOID_PACKAGES_DIR && ./xbps-src pkg brave-bin && sudo xbps-install --repository=hostdir/binpkgs --force brave-bin"
	fi

	return 0
}

# Run the main function
main
