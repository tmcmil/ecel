#!/bin/bash
set -e

ECEL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

OUTPUT_PREFIX="ECEL INSTALLER:"
OUTPUT_ERROR_PREFIX="$OUTPUT_PREFIX ERROR:"

### Helper functions
#
prompt_accepted_Yn() {
    read -r -p "$1 [Y/n] " yn
    case $yn in
        [nN]*) return 1 ;;
        *) return 0 ;;
    esac
}

### Check if running as root
#
if [ "$EUID" -ne 0 ]; then
    echo "$OUTPUT_ERROR_PREFIX Please run this installation as root"
    exit 1
fi

### Install dependencies
#
REQUIRED_PROGRAMS="openjdk-8-jdk zlib1g-dev libpng-dev libxtst-dev python-gtk2 python-tk python-psutil python-pip python-xlib python-dpkt python-appindicator"
REQUIRED_PYTHON_PACKAGES="schedule autopy netifaces"
REQUIRED_PLUGINS="tshark"

for plugin in $REQUIRED_PLUGINS; do
    plugin_prompt="$plugin is not installed. Do you wish to install it now (ECEL will still run, but the $plugin plugin(s) won't)?"
    if ! command -v $plugin >/dev/null 2>&1 && prompt_accepted_Yn "$plugin_prompt"; then
        REQUIRED_PROGRAMS="$REQUIRED_PROGRAMS $plugin"
    fi
done

echo "$OUTPUT_PREFIX Installing dependecies"
if [ -x "/usr/bin/apt-get" ]; then
    apt-get -y install $REQUIRED_PROGRAMS
elif [ -x "/usr/bin/yum" ]; then
    yum install -y $REQUIRED_PROGRAMS
else
    echo "$OUTPUT_ERROR_PREFIX Distribution not supported"
    exit 1
fi

echo "$OUTPUT_PREFIX Installing python dependencies"
python -m pip install pip --upgrade
python -m pip install $REQUIRED_PYTHON_PACKAGES

if prompt_accepted_Yn "Would you like to install snoopy? ECEL will still run without it, but the snoopy plugin will not work."; then
    bash "$ECEL_DIR"/scripts/install-snoopy.sh
fi

### Create plugin configs
# #TODO: do this every time it's necessary
for plugin in "$ECEL_DIR"/plugins/collectors/*; do
    if [ -d "$plugin" ]; then
        scp "$plugin"/config.json.template "$plugin"/config.json
        scp "$plugin"/config_schema.json.template "$plugin"/config_schema.json
    fi
done

### Compile parsers
#
echo "$OUTPUT_PREFIX Compiling parsers" #TODO: Compile new plugins
for plugin in "$ECEL_DIR"/plugins/parsers/*; do
    if [ -d "$plugin" ] && ls "$plugin"/*.java > /dev/null 2>&1; then
        javac "$plugin"/*.java
    fi
done

### Set file permissions
#
echo "$OUTPUT_PREFIX Setting file permissions"
find ./ -name "*.sh" -exec chmod +x {}  \;

### Creating executables
#
echo "$OUTPUT_PREFIX Creating executables"
cat > "$ECEL_DIR"/ecel-gui <<-'EOFecelgui'
	#!/bin/bash

	ECEL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
	if [ "$EUID" -ne 0 ]; then
		echo "ECEL must be run as root"
		exit 1
	fi

	python "$ECEL_DIR"/ecel_gui.py
EOFecelgui
chmod +x "$ECEL_DIR"/ecel-gui
install "$ECEL_DIR"/ecel-gui /usr/local/sbin #TODO: Check for security issues

echo "$OUTPUT_PREFIX Installation Complete"

