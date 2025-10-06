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
