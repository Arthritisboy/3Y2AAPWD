module.exports = {
  branches: ['release'],
  plugins: [
    '@semantic-release/commit-analyzer',
    '@semantic-release/release-notes-generator',
    [
      '@semantic-release/github',
      {
        // Disable creating issues or comments on fail/success
        successComment: false,
        failComment: false,
        failTitle: false,
        // Attach the APK artifact from CI build
        assets: [
          { path: 'frontend/build/app/outputs/flutter-apk/app-release.apk', label: 'APK' }
        ]
      }
    ]
  ],
  preset: 'conventionalcommits',
  releaseRules: [
    { type: 'fix', release: 'patch' },
    { type: 'feat', release: 'minor' },
    { type: 'chore', release: 'minor' },
    { type: 'trigger', release: 'major' } // your custom keyword
  ],
  parserOpts: {
    noteKeywords: ['BREAKING CHANGE', 'trigger']
  }
};
