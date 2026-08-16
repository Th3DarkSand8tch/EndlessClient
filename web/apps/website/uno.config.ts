import {
	defineConfig,
	presetIcons,
	presetTypography,
	presetUno,
	transformerDirectives,
	transformerVariantGroup,
} from 'unocss';

export default defineConfig({
	rules: [
		['parallax-container', { perspective: '10px' }],
		[
			/^parallax-(\d+)$/,
			([, d]) => ({
				transform: `translateZ(-${d}px) scale(${Number.parseInt(d) / 10 + 1})`,
			}),
		],
	],
	shortcuts: {},
	presets: [
		presetUno(),
		presetIcons(),
		presetTypography({
			cssExtend: {
				'blockquote': {
					'border-left': '4px solid rgba(168, 85, 247)',
					'border-radius': '12px',
				},
				'img': {
					'border-radius': '12px',
				},
				'p:first-child': {
					'margin-top': '0',
				},
				'h1, h2, h3': {
					color: 'rgba(46, 16, 72)',
				},
			},
		}),
	],
	transformers: [transformerVariantGroup(), transformerDirectives()],
	theme: {
		// Palette EndlessClient, derivee du logo (E de pierre violette + eclairs).
		//
		// ATTENTION AUX NOMS : l'echelle s'appelle toujours `blue` et la teinte
		// sombre toujours `navy-peony`. Ce sont les noms herites du theme amont,
		// utilises dans ~30 fichiers .astro (`text-blue-500`, `bg-blue-75`...).
		// Seules les VALEURS ont bascule en violet, pour eviter un renommage de
		// masse des classes utilitaires. Lis `blue` comme "accent de marque".
		//
		// Ancres du logo :
		//   #A855F7  violet vif      -> blue-400 / primary-200
		//   #7E22CE  violet profond  -> blue-500
		//   #6B21A8  violet fonce    -> blue-600 / primary-600
		//   #2E1048  pierre sombre   -> navy-peony
		//   #0F0A14  fond nuit       -> dark.background
		colors: {
			'blue': {
				20: 'rgba(243, 232, 255)',
				30: 'rgba(233, 213, 255)',
				50: 'rgba(246, 240, 254)',
				60: 'rgba(88, 28, 135)',
				75: 'rgba(244, 238, 252)',
				100: 'rgba(237, 222, 254)',
				200: 'rgba(226, 205, 253)',
				300: 'rgba(210, 180, 251)',
				400: 'rgba(168, 85, 247)',
				450: 'rgba(147, 51, 234)',
				500: 'rgba(126, 34, 206)',
				600: 'rgba(107, 33, 168)',
				800: 'rgba(45, 16, 71)',
			},
			'green': {
				300: 'rgba(35, 154, 96, 0.5)',
			},
			'gray': {
				50: 'rgba(244, 241, 248)',
				100: 'rgba(205, 198, 216)',
				200: 'rgba(205, 198, 216)',
				400: 'rgba(150, 138, 168)',
				600: 'rgba(45, 42, 50)',
				700: 'rgba(74, 65, 88)',
				800: 'rgba(47, 42, 55)',
			},
			'white': {
				'DEFAULT': 'rgba(255, 255, 255)',
				'1/4': 'rgba(255, 255, 255, 0.25)',
				'light': 'rgba(248, 243, 255)',
			},
			'black': {
				DEFAULT: 'rgba(0, 0, 0)',
			},
			'text': {
				DEFAULT: 'rgba(12, 6, 18)',
				primary: 'rgba(12, 6, 18)',
			},
			// Other
			'navy-peony': 'rgba(46, 16, 72)',
			'lightslategray': 'rgba(150, 128, 178)',
			'primary': {
				100: 'rgba(26, 18, 33)',
				200: 'rgba(147, 51, 234)',
				600: 'rgba(107, 33, 168)',
			},
			'dark': {
				background: 'rgba(15, 10, 20)',
				primary: 'rgba(233, 213, 255)',
				secondary: 'rgba(139, 124, 155)',
			},
		},
		borderRadius: {
			'none': '0',
			'sm': '3px',
			'md': '5px',
			'lg': '8px',
			'xl': '12px',
			'2xl': '16px',
			'3xl': '20px',
			'4xl': '24px',
			'full': '100vw',
		},
		fontSize: {
			// rem starts at 16px on desktop, 14px on tailwind 'sm' and below
			'xxs': ['0.625rem', '1rem'], // 10px
			'xs': ['0.75rem', '1rem'], // 12px
			'sm': ['0.875rem', 'inherit'], // 14px
			'md': ['1rem', 'inherit'], // 16px
			'lg': ['1.125rem', 'inherit'], // 18px
			'xl': ['1.25rem', 'inherit'], // 20px

			'header-sm': ['1.5rem', 'inherit'], // 24px
			'header': ['1.75rem', 'inherit'], // 28px
			'header-lg': ['2rem', 'inherit'], // 32px
			'header-page': ['2.25rem', 'inherit'], // 36px

			'body-sm': ['0.938rem', 'inherit'], // 15px
			'body': ['1rem', 'inherit'], // 16px
			'body-lg': ['1.063rem', 'inherit'], // 17px
		},
		fontFamily: {
			mono: ['"Roboto Mono"', 'monospace'],
		},
		extend: {
			// zIndex: {
			// 	'navbar': '9999', // Nothing should be above the navbar or backdrop
			// 	'navbar-backdrop': '9998',
			// },
			// maxHeight: {
			// 	'3/4-screen': '75vh',
			// 	'4/5-screen': '80vh',
			// },
			// lineHeight: {
			// 	none: '0',
			// },
			// transitionProperty: {
			// 	filter: 'filter',
			// },
		},
	},
});
