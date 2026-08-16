import type { Icon } from 'virtual:astro-icon';

export interface ProjectDownload {
	url: string;
	platform?: 'windows' | 'mac' | 'linux' | 'universal';
	architecture?: 'x86' | 'x64' | 'arm' | 'arm64' | 'universal';
}

export interface Project {
	name: string;
	description: string;
	logo?: Icon;
	tag?: string;
	downloads?: ProjectDownload[];
	descriptionLong?: string;
	hasPage?: boolean;
}

export interface NavbarDropdown {
	name: string;
	description: string;
	path?: string;
	logo?: Icon;
	tag?: string;
}

export interface NavbarElement {
	text?: string;
	logo?: [Icon, number, number];
	path?: string;
	alt?: string;
	dropdown?: NavbarDropdown[];
}

export interface FooterColumn {
	header: string;
	links: Array<{
		text: string;
		url: string;
	}>;
}

export interface Config {
	name: string;
	title: string;
	description: string;
	image: {
		src: string;
		alt: string;
	};
	projects: Project[];
	socials: {
		youtube: string;
		// twitter: string,
		discord: string;
		github: string;
		modrinth: {
			type: 'user' | 'organization';
			id: string;
		};
		skyclient: string;
	};
	navbar: {
		left: NavbarElement[];
		right: NavbarElement[];
	};
	footer: FooterColumn[];
}

// --- Identites externes ----------------------------------------------------
// Le seul endroit a modifier quand un compte est cree ou change.
//
// GITHUB_URL sert de repli : tant qu'un reseau n'a pas de compte, son bouton
// renvoie ici plutot que vers un lien mort ou, pire, vers le compte d'un
// autre projet.
const GITHUB_URL = 'https://github.com/th3darksand8tch/EndlessClient';

// TODO: coller l'invitation Discord (https://discord.gg/xxxxxxx).
const DISCORD_INVITE = '';

// TODO: coller l'URL de la chaine (https://youtube.com/@xxxxxxx).
const YOUTUBE_URL = '';

// TODO: verifier le type reel du compte Modrinth. `organization` et `user`
// ne construisent pas la meme URL et l'un des deux renverra 404.
const MODRINTH_ID = 'endlessclient';
const MODRINTH_TYPE = 'organization' as const;

export const configConst = {
	name: 'EndlessClient',
	title: 'EndlessClient',
	description: 'Mods and tools for Minecraft, built to last',
	image: {
		src: '/logo.png',
		alt: 'EndlessClient Logo',
	},
	projects: getProjects(),
	socials: {
		youtube: YOUTUBE_URL || GITHUB_URL,
		discord: DISCORD_INVITE || GITHUB_URL,
		github: GITHUB_URL,
		modrinth: {
			id: MODRINTH_ID,
			type: MODRINTH_TYPE,
		},
		skyclient: 'https://skyclient.co',
	},
	navbar: {
		left: [
			{
				logo: ['brand.full', 174, 30],
				path: '/',
			},
		],
		right: [
			{
				text: 'Home',
				path: '/',
			},
			{
				text: 'Mods',
				path: '/mods',
			},
			{
				text: 'Projects',
				dropdown: getProjects().map((project) => {
					if (project.hasPage)
						(project as any).path
							= `/projects/${project.name.toLowerCase()}`;

					return project;
				}) as unknown as NavbarDropdown[],
			},
			{
				text: 'About Us',
				path: '/about',
			},
			{
				text: 'Blog',
				path: '/blog',
			},
		],
	},
	footer: [
		{
			header: 'Products',
			links: getProjects()
				.filter(project => project.hasPage === true)
				.map(project => ({
					text: project.name,
					url: `/projects/${project.name.toLowerCase()}`,
				}))
				.concat([
					{
						text: 'Mods',
						url: '/mods',
					},
				]),
		},
		{
			header: 'Organization',
			links: [
				{
					text: 'About us',
					url: '/about',
				},
				{
					text: 'Blog',
					url: '/blog',
				},
				{
					text: 'Branding',
					url: '/branding',
				},
				{
					text: 'Contact us',
					url: '/contact',
				},
				{
					text: 'Documentation',
					url: 'https://docs.endlessclient.dev',
				},
				{
					text: 'Open source',
					url: '/oss',
				},
			],
		},
		{
			header: 'Legal',
			links: [
				{
					text: 'Terms of service',
					url: '/legal/terms',
				},
				{
					text: 'Privacy policy',
					url: '/legal/privacy',
				},
			],
		},
	],
} satisfies Config;

function getProjects(): Project[] {
	return [
		{
			name: 'EndlessConfig',
			description:
				'The next-generation config library for Forge and Fabric',
			logo: 'endlessconfig.minimal',
			hasPage: true,
		},
		{
			name: 'EndlessClient',
			description:
				'The anti-client.',
			logo: 'endlessclient.minimal',
			hasPage: true,
		},
		{
			name: 'EndlessLauncher',
			description:
				'The next-generation launcher for all your Minecraft needs',
			logo: 'endlesslauncher.minimal',
			tag: 'SOON',
		},
	];
}

export default configConst;
