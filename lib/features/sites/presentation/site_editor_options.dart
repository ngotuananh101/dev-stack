const siteConfigEditorOptions = <({String id, String label})>[
  (id: 'nginx', label: 'Nginx'),
  (id: 'apache', label: 'Apache'),
  (id: 'caddy', label: 'Caddy'),
];

const siteLogOptions = <({String id, String label})>[
  (id: 'nginx_access', label: 'Nginx Access'),
  (id: 'nginx_error', label: 'Nginx Error'),
  (id: 'apache_access', label: 'Apache Access'),
  (id: 'apache_error', label: 'Apache Error'),
  (id: 'caddy_access', label: 'Caddy Access'),
  (id: 'caddy_error', label: 'Caddy Runtime'),
];
