#!/bin/bash
# Run this ONCE to generate your release keystore.
# Store the generated labbridge.keystore file SECURELY — never commit it to git.
# Add it to .gitignore.

keytool -genkey -v \
  -keystore labbridge.keystore \
  -alias labbridge \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=LabBridge, OU=Mobile, O=LabBridge, L=Mumbai, S=Maharashtra, C=IN"

echo ""
echo "Keystore created: labbridge.keystore"
echo "Add to your .gitignore and set these environment variables:"
echo "  KEYSTORE_FILE=android/labbridge.keystore"
echo "  KEYSTORE_PASSWORD=<your password>"
echo "  KEY_ALIAS=labbridge"
echo "  KEY_PASSWORD=<your password>"
