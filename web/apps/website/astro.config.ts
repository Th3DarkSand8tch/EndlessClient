import mdx from '@astrojs/mdx';
import node from '@astrojs/node';
import partytown from '@astrojs/partytown';
import sitemap from '@astrojs/sitemap';
import icons from 'astro-icon';

import { defineConfig, envField } from 'astro/config';
import unocss from 'unocss/astro';

// https://astro.build/config
export default defineConfig({
	site: 'https://endlessclient.dev',
	adapter: node({
		mode: 'standalone',
	}),
	output: 'static',
	integrations: [
		unocss({
			injectReset: true,
		}),
		mdx(),
		sitemap(),
		partytown(),
		icons({
			svgoOptions: {
				plugins: [],
			},
		}),
	],
	vite: {
		ssr: {
			noExternal: [
				'smartypants',
				'ua-parser-js',
				'@octokit/core',
				'@octokit/plugin-throttling',
				'@astrojs/markdown-remark',
				'rehype-sanitize'
			]
		},
	},
	experimental: {
		contentIntellisense: true,
	},
	redirects: {
		'/discord': 'https://github.com/th3darksand8tch/EndlessClient',
		'/endlessclient': '/projects/endlessclient',
		'/endlessconfig': '/projects/endlessconfig',
		'/endlessclient-blog': '/blog/endlessclient-announcement',
	},
	env: {
		schema: {
			GITHUB_PAT: envField.string({ context: 'server', access: 'secret', optional: true }),
		},
	},
});
