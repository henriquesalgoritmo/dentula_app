/// Centralized configuration for pages that require an active `pacote`.
///
/// Edit the lists below to add or remove restricted routes/tabs in the future.
const Set<String> blockedRoutesWhenNoPacote = {
  // route names (use the static `routeName` values from screens)
  '/video-feed',
  '/pdf-test',
};

/// If your app uses a tab index-based navigation (like `InitScreen`), list
/// the bottom-navigation indices that should be blocked when user has no
/// `pacoteIds` value. Keep in sync with the `pages` order in `InitScreen`.
const Set<int> blockedTabIndicesWhenNoPacote = {
  0, // Videos
  4, // PDFs (updated after inserting Coordenadas tab)
};
