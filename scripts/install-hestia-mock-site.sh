#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
install-hestia-mock-site.sh USER DOMAIN

Seeds a Hestia domain document root with small static mock pages for local
GoAccess traffic testing.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

if [[ "$#" -ne 2 ]]; then
	usage >&2
	exit 64
fi

user="$1"
domain="$2"
docroot="/home/${user}/web/${domain}/public_html"

if [[ ! "${user}" =~ ^[A-Za-z0-9._-]+$ ]]; then
	printf 'invalid Hestia user: %s\n' "${user}" >&2
	exit 64
fi

if [[ ! "${domain}" =~ ^[A-Za-z0-9._-]+$ ]]; then
	printf 'invalid domain: %s\n' "${domain}" >&2
	exit 64
fi

if [[ ! -d "${docroot}" ]]; then
	printf 'document root does not exist: %s\n' "${docroot}" >&2
	exit 1
fi

install -d -m 0755 -o "${user}" -g "${user}" \
	"${docroot}/assets" \
	"${docroot}/blog" \
	"${docroot}/docs" \
	"${docroot}/product" \
	"${docroot}/status"

write_page() {
	local path="$1"
	local title="$2"
	local eyebrow="$3"
	local body="$4"
	local full_path="${docroot}/${path}"

	install -d -m 0755 -o "${user}" -g "${user}" "$(dirname "${full_path}")"
	if [[ -d "${full_path}" ]]; then
		rm -rf "${full_path}"
	fi
	cat > "${full_path}" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${title} - ${domain}</title>
  <link rel="stylesheet" href="/assets/site.css">
</head>
<body>
  <header>
    <a class="brand" href="/">${domain}</a>
    <nav>
      <a href="/pricing">Pricing</a>
      <a href="/product/tour">Product</a>
      <a href="/blog/post-1">Blog</a>
      <a href="/docs/start">Docs</a>
      <a href="/status/">Status</a>
      <a href="/contact">Contact</a>
    </nav>
  </header>
  <main>
    <p class="eyebrow">${eyebrow}</p>
    <h1>${title}</h1>
    <p>${body}</p>
    <section class="grid">
      <a href="/pricing-1">Starter plan</a>
      <a href="/pricing-2">Growth plan</a>
      <a href="/blog/post-2">Latest notes</a>
      <a href="/docs/api">API docs</a>
    </section>
  </main>
</body>
</html>
HTML
	chown "${user}:${user}" "${full_path}"
	chmod 0644 "${full_path}"
}

cat > "${docroot}/assets/site.css" <<'CSS'
:root {
  color-scheme: light dark;
  --bg: #f6f7f8;
  --fg: #202327;
  --muted: #68707a;
  --panel: #ffffff;
  --line: #d8dde3;
  --accent: #2f6fed;
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg: #202226;
    --fg: #f4f5f6;
    --muted: #b7bdc5;
    --panel: #2a2d32;
    --line: #3a3f46;
    --accent: #8bb4ff;
  }
}

body {
  margin: 0;
  background: var(--bg);
  color: var(--fg);
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  line-height: 1.55;
}

header {
  display: flex;
  gap: 24px;
  align-items: center;
  justify-content: space-between;
  padding: 18px clamp(18px, 5vw, 56px);
  border-bottom: 1px solid var(--line);
  background: var(--panel);
}

a {
  color: var(--accent);
  text-decoration: none;
}

nav {
  display: flex;
  flex-wrap: wrap;
  gap: 14px;
}

.brand {
  color: var(--fg);
  font-weight: 700;
}

main {
  max-width: 860px;
  padding: 56px clamp(18px, 5vw, 56px);
}

.eyebrow {
  margin: 0 0 12px;
  color: var(--muted);
  text-transform: uppercase;
  font-size: 0.78rem;
  letter-spacing: 0.08em;
}

h1 {
  margin: 0 0 16px;
  font-size: clamp(2rem, 6vw, 4.2rem);
  line-height: 1.05;
  letter-spacing: 0;
}

.grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 12px;
  margin-top: 32px;
}

.grid a {
  display: block;
  padding: 16px;
  background: var(--panel);
  border: 1px solid var(--line);
  border-radius: 8px;
}
CSS

write_page "index.html" "Local analytics test site" "Mock home" "This page exists so GoAccess development traffic produces useful successful requests instead of a wall of 404s."
write_page "pricing/index.html" "Pricing" "Plans" "A normal pricing page for repeatable local traffic generation."
write_page "pricing.html" "Pricing" "Plans" "A normal pricing page for clients that request the .html variant."
write_page "about/index.html" "About" "Company" "A quiet about page used by local GoAccess smoke traffic."
write_page "contact/index.html" "Contact" "Sales" "A mock contact page for successful form-page hits."
write_page "product/tour/index.html" "Product tour" "Product" "A mock product tour page with enough links to click around."
write_page "docs/start/index.html" "Getting started" "Docs" "A mock documentation start page."
write_page "docs/api/index.html" "API reference" "Docs" "A mock API reference page."
write_page "status/index.html" "System status" "Status" "Everything is operational in this local fixture."

for i in $(seq 1 20); do
	write_page "pricing-${i}" "Pricing scenario ${i}" "Pricing" "A successful pricing variant used by traffic simulation run ${i}."
	write_page "blog/post-${i}" "Release note ${i}" "Blog" "A successful mock blog post used by traffic simulation run ${i}."
done

cat > "${docroot}/robots.txt" <<EOF_ROBOTS
User-agent: *
Allow: /
Sitemap: http://${domain}/sitemap.xml
EOF_ROBOTS

cat > "${docroot}/sitemap.xml" <<EOF_SITEMAP
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>http://${domain}/</loc></url>
  <url><loc>http://${domain}/pricing/</loc></url>
  <url><loc>http://${domain}/blog/post-1/</loc></url>
  <url><loc>http://${domain}/docs/start/</loc></url>
</urlset>
EOF_SITEMAP

: > "${docroot}/favicon.ico"

chown -R "${user}:${user}" "${docroot}"
find "${docroot}" -type d -exec chmod 0755 {} +
find "${docroot}" -type f -exec chmod 0644 {} +

printf 'mock site installed: %s\n' "${docroot}"
