#!/bin/bash
# Run this ONCE to generate your release keystore.
# Store the generated cueflex.keystore file SECURELY — never commit it to git.
# Add it to .gitignore.

keytool -genkey -v \
  -keystore cueflex.keystore \
  -alias cueflex \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=CueFlex, OU=Mobile, O=CueFlex, L=Mumbai, S=Maharashtra, C=IN"

echo ""
echo "Keystore created: cueflex.keystore"
echo "Add to your .gitignore and set these environment variables:"
echo "  KEYSTORE_FILE=android/cueflex.keystore"
echo "  KEYSTORE_PASSWORD=<your password>"
echo "  KEY_ALIAS=cueflex"
echo "  KEY_PASSWORD=<your password>"
