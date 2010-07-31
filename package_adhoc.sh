#!/bin/sh
# package_adhoc.sh - create provisioned ad-hoc release for iPhone app
# 	(K) 2009 - Marc Powell - mr_marc@makerlab.org - http://iphonedevblog.makerlab.org
#
# REQUISITES:
#	{cwd} 			: xCode project directory, run from this dir
#	{cwd}/build 	: xcode app build dir - if not found, xcodebuild is run
#	{cwd}/build/{config}-iphoneos	: app directory to be packaged- built if not found
#
# OPTIONAL:
#	{cwd}/_distfiles	: files to include in provisioned release .zipfile
#				(README.TXT, iTunesArtwork, mobileprovision cert)
#	{cwd}/_distfiles/iTunesArtwork 				: 512x512 png used by iTunes
#	{cwd}/_distfiles/{app_name}.mobileprovision	: provisioned distribution cert
#
# PRODUCTS:
#	{cwd}/_release 						: release target dir (created)
#	{cwd}/_release/{release_name}.zip  : provisioned release, distribute this
# 
# HOW TO USE THIS TO SHIP A PROVISIONED RELEASE
# 	1. Increment App Bundle Version number in Xcode
#		Info.plist property "Bundle Version" -> 1.154, SAVE
#	2. Copy release asset files to dist directory (only have to do this once)
#		$ cp *.mobileprovision iTunesArtwork README.txt _distfiles/
# 	3. Run this script to create a provisioned ad-hoc release
#		$ ./make_release.sh HelloWorld_v154 Debug
# 	4. Distribute the resulting zipfile to your beta testers
#		$ scp _release/HelloWorld_v154.zip 
#
# BETA TESTER INSTALL
#	1. Download and open provisioned release .zip
#	2. Drag .mobileprovision cert into iTunes (only have to do this once, unless cert is updated)
#	3. Double click HelloWorld.ipa, iTunes will install it to Applications
#	4. Sync your mobile device, the Provisioned Release will be installed
# 

# default configuration, overwritten from commandline
CONFIGURATION="Ad Hoc" # or Release or Debug

# location of files included in dist (.mobileprovision, iTunesArtwork, README)
DISTDIR="_distfiles"

usage ()
	{
	echo "usage: $0 release_name [build_configuration]"	
	echo "ex: $0 HelloWorld_v153"
	echo "ex: $0 HelloWorld_v154 Debug"
	exit;
	}

build_xcode ()
	{
	xcodebuild -configuration "$CONFIGURATION"
	}

# MUST SET directory for release to be packaged
RELEASE="$1"
if test "$RELEASE"x = x; then
	usage
fi

# OVERWRITE don't allow removing of previous packaged releases
RELEASEBASE="_release"
RELEASEDIR="$RELEASEBASE/$RELEASE"
if test -d "$RELEASEDIR"; then
	echo "ERROR: $RELEASEDIR already exists, erase it"
	usage
fi

# CONFIGURATION for xcode build can be overridden from commandline
NEWCONFIG="$2"
if ! test "$NEWCONFIG"x = x; then
	CONFIGURATION="$NEWCONFIG"
fi

# XCODE check build available for specified configuration
CHECKCONFIGURATION=`xcodebuild -list | egrep "$CONFIGURATION($|\ )"`
if test "$CHECKCONFIGURATION"x = x; then
	echo "ERROR: xcodebuild could not find valid build configuration $CONFIGURATION"
	echo
	xcodebuild -list
	echo
	usage
fi

#######
echo "=== Building distribution package for $RELEASE"

# XCODE make sure buildpath exists for configuration, build if missing
BUILDPATH="build/$CONFIGURATION-iphoneos/"
if test ! -d "$BUILDPATH"; then
	echo "missing $CONFIGURATION build dir in $BUILDPATH, trying to build"
	build_xcode
	if test ! -d "$BUILDPATH"; then
		echo "ERROR: xcodebuild could not build configuration $CONGIRUATION ($BUILDPATH)"
		usage
	fi
	echo "=== Successfully built configuration $CONFIGURATION ($BUILDPATH)"
fi

# HACK : accomodate configurations with spaces, chdir to determine app name
cd "$BUILDPATH"
# derive name of .app dir (application)
APPDIR=`ls -d *.app`
cd ../..

APPPATH="$BUILDPATH/$APPDIR"
if test "$APPDIR"x = x; then
	APPPATH="$BUILDPATH/.app"
fi
# XCODE make sure app dir exists in buildpath, build if missing
if test ! -d "$APPPATH"; then
	echo "missing $APPPATH build in $BUILDPATH, trying to build"
	build_xcode

	# HACK : accomodate configurations with spaces, chdir to determine app name
	cd "$BUILDPATH"
	# derive name of .app dir (application)
	APPDIR=`ls -d *.app`
	cd ../..

	# check again for APPDIR/APPPATH
	APPPATH="$BUILDPATH/$APPDIR"
	if test "$APPDIR"x = x; then
		APPPATH="$BUILDPATH/.app"
	fi

	if test ! -d "$APPPATH"; then
		echo "ERROR: xcodebuild could not build $APPPATH configuration $CONGIRUATION ($BUILDPATH)"
		usage
	fi
	echo "=== Successfully built $APPDIR configuration $CONFIGURATION ($BUILDPATH)"
fi

# Create directory for release package
echo " -  Creating release dir"
mkdir -p "$RELEASEDIR"

# Copy other files
cp $DISTDIR/* "$RELEASEDIR"

# .IPA file: iphone app archive file, installable by itunes
IPA=`echo $APPDIR | sed "s/\.app/\.ipa/"`
echo " -  Creating $IPA payload"
mkdir -p "$RELEASEDIR/Payload/"
# Copy built .app to payload/ itunes-specific install dir
cp -rp "$APPPATH" "$RELEASEDIR/Payload/"

# Build .IPA file
#	this is just a zipfile with a payload/ dir with the .app, and artwork
cd "$RELEASEDIR"
# include 512x512 png of artwork, if foudn
if test -f "iTunesArtwork"; then
	zip -r $IPA iTunesArtwork Payload/
	rm -rf Payload iTunesArtwork
else 
	zip -r $IPA Payload/
	rm -rf Payload 
fi

cd ..

# Create .zip packaged Distribution
echo " -  Compressing release"
zip -r "$RELEASE.zip" "$RELEASE"

echo "=== Build complete for $RELEASEBASE/$RELEASE.zip"

#
scp "$RELEASEBASE/$RELEASE.zip" andy@lumi.infiniterecursion.com.au:/var/www/fm-dist/
