#!/bin/bash
set -e

v=(${VERSION//./ })
branch="${v[0]}.${v[1]}"
version="${v[0]}.${v[1]}.${v[2]}"

echo "Runtime environment"
echo -e "branch: \t\t$branch"
echo -e "version: \t\t$version"

# Download source code
curl -o License.java -s https://raw.githubusercontent.com/elastic/elasticsearch/$branch/x-pack/plugin/core/src/main/java/org/elasticsearch/license/License.java
curl -o LicenseVerifier.java -s https://raw.githubusercontent.com/elastic/elasticsearch/$branch/x-pack/plugin/core/src/main/java/org/elasticsearch/license/LicenseVerifier.java

# For v8, we need XPackBuild.java
if [ "${v[0]}" = "8" ]; then
    curl -o XPackBuild.java -s https://raw.githubusercontent.com/elastic/elasticsearch/$branch/x-pack/plugin/core/src/main/java/org/elasticsearch/xpack/core/XPackBuild.java
    # Edit XPackBuild.java
    sed -i 's/path.toString().endsWith(".jar")/false/g' XPackBuild.java
fi

# Edit LicenseVerifier.java
sed -i '/void validate()/{h;s/validate/validate2/;x;G}' License.java
sed -i '/void validate()/ s/$/}/' License.java

# Edit LicenseVerifier.java
sed -i '/boolean verifyLicense(/{h;s/verifyLicense/verifyLicense2/;x;G}' LicenseVerifier.java
sed -i '/boolean verifyLicense(/ s/$/return true;}/' LicenseVerifier.java

# Build class files
javac -cp "/usr/share/elasticsearch/lib/*:/usr/share/elasticsearch/modules/x-pack-core/*" LicenseVerifier.java
javac -cp "/usr/share/elasticsearch/lib/*:/usr/share/elasticsearch/modules/x-pack-core/*" License.java

if [ "${v[0]}" = "8" ]; then
    javac -cp "/usr/share/elasticsearch/lib/*:/usr/share/elasticsearch/modules/x-pack-core/*" XPackBuild.java
fi

# Build jar file
cp /usr/share/elasticsearch/modules/x-pack-core/x-pack-core-$version.jar x-pack-core-$version.jar
unzip -q x-pack-core-$version.jar -d ./x-pack-core-$version

# For v9, remove Build.class to avoid jar hell
if [ "${v[0]}" = "9" ]; then
    rm -f ./x-pack-core-$version/org/elasticsearch/Build.class
fi

# Copy patched classes
cp LicenseVerifier.class ./x-pack-core-$version/org/elasticsearch/license/
cp License.class ./x-pack-core-$version/org/elasticsearch/license/

if [ "${v[0]}" = "8" ]; then
    cp XPackBuild.class ./x-pack-core-$version/org/elasticsearch/xpack/core/
fi

jar -cf x-pack-core-$version.patched.jar -C x-pack-core-$version/ .

mv x-pack-core-$version.patched.jar x-pack-core-$version.jar