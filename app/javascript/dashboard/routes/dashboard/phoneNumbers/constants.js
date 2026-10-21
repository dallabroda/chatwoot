// Labels per asset type; literal keys keep the strings statically extractable
export const metaAssetLabels = t => ({
  pages: t('META_ASSETS_PAGE.TYPES.PAGES'),
  ad_accounts: t('META_ASSETS_PAGE.TYPES.AD_ACCOUNTS'),
  datasets: t('META_ASSETS_PAGE.TYPES.DATASETS'),
  catalogs: t('META_ASSETS_PAGE.TYPES.CATALOGS'),
  instagram_accounts: t('META_ASSETS_PAGE.TYPES.INSTAGRAM_ACCOUNTS'),
});

// Meta asset types shared during embedded signup, keyed as returned by the
// whatsapp_shared_assets API. Each gets its own route so the sidebar can
// highlight the active one.
export const META_ASSET_TYPES = [
  { type: 'pages', routeName: 'meta_assets_pages', icon: 'i-lucide-file-text' },
  {
    type: 'ad_accounts',
    routeName: 'meta_assets_ad_accounts',
    icon: 'i-lucide-megaphone',
  },
  {
    type: 'datasets',
    routeName: 'meta_assets_datasets',
    icon: 'i-lucide-database',
  },
  {
    type: 'catalogs',
    routeName: 'meta_assets_catalogs',
    icon: 'i-lucide-book-open',
  },
  {
    type: 'instagram_accounts',
    routeName: 'meta_assets_instagram_accounts',
    icon: 'i-lucide-instagram',
  },
];
