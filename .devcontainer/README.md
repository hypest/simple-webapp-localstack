Build with Zscaler CA

If your corporate network intercepts TLS (Zscaler, proxy), build steps that curl/apt inside images will fail unless the intercepting CA is trusted.

This repository includes a BuildKit-enabled Dockerfile that can accept a build secret named `zscaler_ca` and install it into the image trust store during build.

Quick steps:

1. Export the Zscaler root certificate to WSL, for example:

   cp /mnt/c/Users/<YourWindowsUser>/Downloads/ZscalerRootCA.crt ~/.certs/zscaler.crt

2. Run the helper script to build the devcontainer image with the secret:

   ./.devcontainer/build-with-secret.sh

3. After the image is built, point VS Code to use the prebuilt image by editing `.devcontainer/devcontainer.json` and replacing the `build` block with:

   {
   "image": "my-devcontainer:local"
   }

4. Reopen the folder in container (Rebuild container). This avoids passing the secret through the devcontainer build pipeline and keeps the CA out of your final image layers.

If you'd like me to update `devcontainer.json` to reference the prebuilt image automatically, tell me and I'll prepare a patch (you can revert it when you want to rebuild).

Using this repository in GitHub Codespaces
----------------------------------------

GitHub Codespaces doesn't allow using local-only prebuilt images that were built with private build secrets. To support Codespaces while keeping your corporate Zscaler CA private, this repository includes a runtime post-create installer that can consume a Codespaces secret.

1. Create a repository or organization secret named `ZSCALER_CERT` containing your Zscaler root certificate. You can provide the certificate as either:
    - Raw PEM text (-----BEGIN CERTIFICATE----- ...), or
    - Base64-encoded PEM (no newlines).

2. In your Codespace, add that secret as an environment variable for the Codespace. In the Codespaces UI you can add repository secrets as environment variables when creating the Codespace.

3. The devcontainer's `postCreateCommand` runs `.devcontainer/scripts/install_zscaler_cert.sh` which will detect `ZSCALER_CERT`, write it to `/usr/local/share/ca-certificates/zscaler.crt`, and run `update-ca-certificates` so tools like `apt`/`curl` trust your corporate TLS interception.

Notes and alternatives
- If you prefer not to store the PEM directly, you can base64-encode it yourself and store the base64 string in the `ZSCALER_CERT` secret; the installer will decode it.
- Codespaces runs the post-create script as the non-root user. The script uses `sudo` to write into system trust stores. Ensure your Codespace user has sudo rights (default Codespaces images do).
- For local development where you control the Docker build, continue to use `.devcontainer/build-with-secret.sh` which passes the cert as a BuildKit secret to avoid baking it into image layers.
