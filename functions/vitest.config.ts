import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    // Tests share one set of emulators; run files one at a time.
    fileParallelism: false,
    testTimeout: 15000,
    hookTimeout: 30000,
    // Lets the Admin SDK (initializeApp() in src/config.ts) find the project.
    env: { GCLOUD_PROJECT: "prepnotes-635d6" },
  },
});
