import type { APIRoute } from 'astro';
import { github, RELEASE_REPOSITORY } from '@utils/github';

export const prerender = false;

interface DownloadStats {
	total: number;
	accounts: Record<string, number>;
	timestamp: number;
}

const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour
let cache: DownloadStats | null = null;

// Comptes GitHub dont on additionne les telechargements de releases.
// th3darksand8tch est un compte utilisateur : l'enumeration de ses depots
// passe par /users/{username}/repos. /orgs/{org}/repos repondrait 404.
const ACCOUNTS = [RELEASE_REPOSITORY.owner];
async function fetchJson<T>(url: string): Promise<T> {
	const res = await fetch(url);
	if (!res.ok)
		throw new Error(`Fetch failed: ${res.status} ${res.statusText} for ${url}`);
	return res.json();
}

interface ModrinthProject {
	downloads: number;
}

async function countDownloads(): Promise<DownloadStats> {
	let total = 0;
	const accounts: Record<string, number> = {};

	for (const username of ACCOUNTS) {
		let accountDownloads = 0;
		const { data: repos } = await github.request('GET /users/{username}/repos', {
			username,
			per_page: 100,
		});

		const repoResults = await Promise.allSettled(repos.map(async (repo) => {
			let repoTotal = 0;

			const { data: releases } = await github.request('GET /repos/{owner}/{repo}/releases', {
				owner: username,
				repo: repo.name,
				per_page: 100,
			});

			for (const release of releases)
				for (const asset of release.assets)
					repoTotal += asset.download_count;

			if (repo.homepage?.includes('modrinth')) {
				const slug = repo.homepage.replace(/\/+$/, '').split('/').pop();
				if (slug)
					try {
						const project = await fetchJson<ModrinthProject>(
							`https://api.modrinth.com/v2/project/${slug}`,
						);
						repoTotal += project.downloads;
					}
					catch { /* modrinth project may not exist */ }
			}

			return repoTotal;
		}));

		for (const result of repoResults)
			if (result.status === 'fulfilled')
				accountDownloads += result.value;

		accounts[username] = accountDownloads;
		total += accountDownloads;
	}

	return { total, accounts, timestamp: Date.now() };
}

export const GET: APIRoute = async () => {
	if (cache && (Date.now() - cache.timestamp) < CACHE_TTL_MS)
		return Response.json(cache);

	try {
		cache = await countDownloads();
		return Response.json(cache);
	}
	catch (err) {
		const message = err instanceof Error ? err.message : 'Unknown error';
		console.error('[/api/downloads]', message);

		if (cache)
			return Response.json(cache);

		return Response.json({ error: message }, { status: 502 });
	}
};
