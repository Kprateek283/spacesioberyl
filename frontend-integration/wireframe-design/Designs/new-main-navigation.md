<!DOCTYPE html>

<html class="light" lang="en"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>Execution Jobs Dashboard - Enterprise Suite</title>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600;700&amp;family=Inter:wght@400;500;600;700&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<script id="tailwind-config">
        tailwind.config = {
            darkMode: "class",
            theme: {
                extend: {
                    colors: {
                        "surface-container-lowest": "#ffffff",
                        "surface-container-high": "#dee8ff",
                        "on-tertiary-fixed": "#271900",
                        "surface-bright": "#f9f9ff",
                        "error-container": "#ffdad6",
                        "secondary-container": "#d2e4fb",
                        "on-primary-fixed-variant": "#0e5138",
                        "on-surface": "#111c2c",
                        "tertiary-container": "#7c5900",
                        "inverse-on-surface": "#ebf1ff",
                        "on-primary-fixed": "#002114",
                        "on-surface-variant": "#404943",
                        "surface": "#f9f9ff",
                        "primary-fixed": "#b1f0ce",
                        "on-secondary-fixed-variant": "#38485a",
                        "on-primary": "#ffffff",
                        "inverse-surface": "#263142",
                        "primary-container": "#2d6a4f",
                        "secondary-fixed": "#d2e4fb",
                        "on-secondary-container": "#556679",
                        "error": "#ba1a1a",
                        "tertiary-fixed-dim": "#f7bd48",
                        "background": "#f9f9ff",
                        "secondary-fixed-dim": "#b7c8de",
                        "surface-dim": "#cfdaf1",
                        "surface-container-highest": "#d8e3fa",
                        "on-tertiary-fixed-variant": "#5d4200",
                        "secondary": "#4f6073",
                        "outline-variant": "#bfc9c1",
                        "surface-container": "#e7eeff",
                        "tertiary": "#5e4300",
                        "on-tertiary-container": "#ffd384",
                        "surface-container-low": "#f0f3ff",
                        "on-tertiary": "#ffffff",
                        "on-secondary-fixed": "#0b1d2d",
                        "tertiary-fixed": "#ffdea6",
                        "on-error": "#ffffff",
                        "on-background": "#111c2c",
                        "surface-variant": "#d8e3fa",
                        "primary": "#0f5238",
                        "outline": "#707973",
                        "on-primary-container": "#a8e7c5",
                        "primary-fixed-dim": "#95d4b3",
                        "on-secondary": "#ffffff",
                        "on-error-container": "#93000a",
                        "surface-tint": "#2c694e",
                        "inverse-primary": "#95d4b3"
                    },
                    borderRadius: {
                        "DEFAULT": "0.25rem",
                        "lg": "0.5rem",
                        "xl": "0.75rem",
                        "full": "9999px"
                    },
                    spacing: {
                        "stack-md": "16px",
                        "stack-lg": "24px",
                        "gutter": "24px",
                        "container-padding-mobile": "16px",
                        "unit": "8px",
                        "stack-sm": "8px",
                        "container-padding-desktop": "32px"
                    },
                    fontFamily: {
                        "headline-sm": ["IBM Plex Sans"],
                        "label-md": ["Inter"],
                        "display-lg": ["IBM Plex Sans"],
                        "headline-lg-mobile": ["IBM Plex Sans"],
                        "headline-md": ["IBM Plex Sans"],
                        "body-md": ["Inter"],
                        "label-lg": ["Inter"],
                        "body-sm": ["Inter"],
                        "headline-lg": ["IBM Plex Sans"],
                        "body-lg": ["Inter"]
                    },
                    fontSize: {
                        "headline-sm": ["20px", { lineHeight: "28px", fontWeight: "500" }],
                        "label-md": ["12px", { lineHeight: "16px", letterSpacing: "0.05em", fontWeight: "600" }],
                        "display-lg": ["48px", { lineHeight: "56px", letterSpacing: "-0.02em", fontWeight: "600" }],
                        "headline-lg-mobile": ["28px", { lineHeight: "36px", fontWeight: "600" }],
                        "headline-md": ["24px", { lineHeight: "32px", fontWeight: "500" }],
                        "body-md": ["16px", { lineHeight: "24px", fontWeight: "400" }],
                        "label-lg": ["14px", { lineHeight: "20px", letterSpacing: "0.02em", fontWeight: "600" }],
                        "body-sm": ["14px", { lineHeight: "20px", fontWeight: "400" }],
                        "headline-lg": ["32px", { lineHeight: "40px", letterSpacing: "-0.01em", fontWeight: "600" }],
                        "body-lg": ["18px", { lineHeight: "28px", fontWeight: "400" }]
                    }
                }
            }
        }
    </script>
<style>
        .pb-safe { padding-bottom: env(safe-area-inset-bottom); }
    </style>
<style>
    body {
      min-height: max(884px, 100dvh);
    }
  </style>
  </head>
<body class="bg-background text-on-background font-body-md min-h-screen flex flex-col">
<!-- TopAppBar -->
<header class="bg-surface dark:bg-inverse-surface border-b border-outline-variant dark:border-outline docked full-width top-0 z-40">
<div class="flex justify-between items-center w-full px-container-padding-mobile md:px-container-padding-desktop h-16">
<div class="flex items-center gap-4">
<!-- Mobile Menu Button (hidden on desktop nav logic but kept for safety if needed) -->
<button class="md:hidden text-on-surface-variant dark:text-surface-variant hover:bg-surface-container-low dark:hover:bg-surface-container-highest transition-colors p-2 rounded-full">
<span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 0;">menu</span>
</button>
<div class="font-headline-md text-headline-md font-semibold text-primary dark:text-primary-fixed">
                    Enterprise Suite
                </div>
</div>
<!-- Desktop Nav Cluster (Web Only) -->
<nav class="hidden md:flex items-center gap-8">
<a class="text-on-surface-variant dark:text-surface-variant hover:bg-surface-container-low dark:hover:bg-surface-container-highest transition-colors px-3 py-2 rounded-md font-label-md text-label-md" href="#">Home</a>
<a class="text-on-surface-variant dark:text-surface-variant hover:bg-surface-container-low dark:hover:bg-surface-container-highest transition-colors px-3 py-2 rounded-md font-label-md text-label-md" href="#">CRM</a>
<a class="text-on-surface-variant dark:text-surface-variant hover:bg-surface-container-low dark:hover:bg-surface-container-highest transition-colors px-3 py-2 rounded-md font-label-md text-label-md" href="#">Logistics</a>
<a class="text-primary dark:text-primary-fixed font-bold px-3 py-2 rounded-md font-label-md text-label-md" href="#">Execution</a>
<a class="text-on-surface-variant dark:text-surface-variant hover:bg-surface-container-low dark:hover:bg-surface-container-highest transition-colors px-3 py-2 rounded-md font-label-md text-label-md" href="#">HR</a>
</nav>
<div class="flex items-center gap-4">
<button class="text-primary dark:text-primary-fixed-dim hover:bg-surface-container-low dark:hover:bg-surface-container-highest transition-colors p-2 rounded-full">
<span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 0;">notifications</span>
</button>
<button class="w-8 h-8 rounded-full bg-primary-container text-on-primary-container flex items-center justify-center font-label-lg text-label-lg overflow-hidden ring-2 ring-transparent focus:ring-primary outline-none">
                    UP
                </button>
</div>
</div>
</header>
<!-- Main Content Canvas -->
<main class="flex-grow w-full px-container-padding-mobile md:px-container-padding-desktop py-stack-lg max-w-7xl mx-auto pb-32 md:pb-stack-lg">
<!-- Page Header & Actions -->
<div class="flex flex-col md:flex-row md:items-center justify-between gap-stack-md mb-stack-lg">
<div>
<h1 class="font-headline-lg-mobile md:font-headline-lg text-headline-lg-mobile md:text-headline-lg text-on-background">Site Installations</h1>
<p class="font-body-md text-body-md text-on-surface-variant mt-1">Manage and track ongoing execution jobs.</p>
</div>
<div class="flex items-center gap-stack-sm">
<button class="bg-primary text-on-primary font-label-lg text-label-lg px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-surface-tint transition-colors shadow-sm">
<span class="material-symbols-outlined text-[18px]">add</span>
                    Create Installation
                </button>
</div>
</div>
<!-- Tabbed Interface -->
<div class="border-b border-outline-variant mb-stack-lg">
<nav aria-label="Tabs" class="-mb-px flex gap-stack-lg">
<button aria-current="page" class="border-primary text-primary border-b-2 py-4 px-1 font-label-lg text-label-lg whitespace-nowrap">
                    Active Sites
                </button>
<button class="border-transparent text-on-surface-variant hover:text-on-surface hover:border-outline-variant border-b-2 py-4 px-1 font-label-lg text-label-lg whitespace-nowrap">
                    Completed Sites
                </button>
</nav>
</div>
<!-- Job Cards Grid (Bento style / Asymmetric) -->
<div class="grid grid-cols-1 lg:grid-cols-12 gap-gutter">
<!-- Card 1: High Priority / In Progress (Spans more columns on desktop) -->
<div class="lg:col-span-8 bg-surface-container-lowest border border-outline-variant rounded-xl overflow-hidden hover:shadow-[0px_4px_12px_rgba(26,43,60,0.08)] transition-shadow duration-200 flex flex-col relative">
<!-- Status Bar Left -->
<div class="absolute left-0 top-0 bottom-0 w-2 bg-[#F59E0B]"></div>
<div class="p-stack-lg flex-grow pl-6">
<div class="flex justify-between items-start mb-stack-md">
<div>
<span class="font-label-md text-label-md text-on-surface-variant tracking-wider uppercase">Order ID: #ORD-2023-8942</span>
<h2 class="font-headline-sm text-headline-sm text-on-surface mt-1">Tech Hub Alpha - Level 4 Fitout</h2>
</div>
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full font-label-md text-label-md bg-[#FFFBEB] text-[#B45309] border border-[#FDE68A]">
                            in_progress
                        </span>
</div>
<div class="grid grid-cols-1 sm:grid-cols-2 gap-stack-md mb-stack-lg">
<div class="flex items-start gap-2">
<span class="material-symbols-outlined text-outline mt-0.5 text-[20px]">location_on</span>
<div>
<p class="font-body-sm text-body-sm text-on-surface-variant">Client Address</p>
<p class="font-body-md text-body-md text-on-surface">100 Silicon Ave, Suite 400<br/>San Francisco, CA 94105</p>
</div>
</div>
<div class="flex items-start gap-2">
<span class="material-symbols-outlined text-outline mt-0.5 text-[20px]">engineering</span>
<div>
<p class="font-body-sm text-body-sm text-on-surface-variant">Tech Manager</p>
<p class="font-body-md text-body-md text-on-surface">Sarah Jenkins</p>
</div>
</div>
</div>
<!-- Progress Indicator -->
<div class="mt-auto">
<div class="flex justify-between font-label-md text-label-md mb-2">
<span class="text-primary font-bold">Procurement</span>
<span class="text-primary font-bold">Site Prep</span>
<span class="text-primary font-bold">Installation</span>
<span class="text-outline">Signoff</span>
</div>
<div class="h-2 w-full bg-surface-variant rounded-full overflow-hidden flex">
<div class="h-full bg-primary w-1/4 border-r border-surface-container-lowest"></div>
<div class="h-full bg-primary w-1/4 border-r border-surface-container-lowest"></div>
<div class="h-full bg-primary w-1/4 relative overflow-hidden">
<div class="absolute inset-0 bg-white/20 animate-pulse"></div>
</div>
<div class="h-full bg-surface-variant w-1/4"></div>
</div>
</div>
</div>
<div class="bg-surface-container px-stack-lg py-stack-sm flex justify-end border-t border-outline-variant pl-6">
<button class="font-label-lg text-label-lg text-primary hover:text-surface-tint transition-colors">View Details</button>
</div>
</div>
<!-- Card 2: Standard Card -->
<div class="lg:col-span-4 bg-surface-container-lowest border border-outline-variant rounded-xl overflow-hidden hover:shadow-[0px_4px_12px_rgba(26,43,60,0.08)] transition-shadow duration-200 flex flex-col relative">
<!-- Status Bar Left -->
<div class="absolute left-0 top-0 bottom-0 w-2 bg-primary"></div>
<div class="p-stack-lg flex-grow pl-6">
<div class="flex justify-between items-start mb-stack-md">
<div>
<span class="font-label-md text-label-md text-on-surface-variant tracking-wider uppercase">#ORD-2023-8945</span>
<h2 class="font-headline-sm text-headline-sm text-on-surface mt-1 line-clamp-2">Metro Server Rack Install</h2>
</div>
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full font-label-md text-label-md bg-primary-container text-on-primary-container border border-primary-fixed-dim shrink-0">
                            client_approved
                        </span>
</div>
<div class="flex flex-col gap-stack-md mb-stack-lg">
<div class="flex items-start gap-2">
<span class="material-symbols-outlined text-outline text-[20px]">location_on</span>
<p class="font-body-sm text-body-sm text-on-surface line-clamp-1">45 Industrial Pkwy, Bldg B</p>
</div>
<div class="flex items-start gap-2">
<span class="material-symbols-outlined text-outline text-[20px]">engineering</span>
<p class="font-body-sm text-body-sm text-on-surface">Michael Chang</p>
</div>
</div>
<!-- Progress Indicator -->
<div class="mt-auto pt-4 border-t border-outline-variant">
<div class="flex justify-between font-label-md text-label-md mb-2">
<span class="text-primary font-bold">Prep</span>
<span class="text-primary font-bold">Install</span>
<span class="text-primary font-bold">Signoff</span>
</div>
<div class="h-2 w-full bg-surface-variant rounded-full overflow-hidden flex">
<div class="h-full bg-primary w-1/3 border-r border-surface-container-lowest"></div>
<div class="h-full bg-primary w-1/3 border-r border-surface-container-lowest"></div>
<div class="h-full bg-primary w-1/3 relative overflow-hidden">
<div class="absolute inset-0 bg-white/20 animate-pulse"></div>
</div>
</div>
</div>
</div>
</div>
<!-- Card 3: Early Stage -->
<div class="lg:col-span-6 bg-surface-container-lowest border border-outline-variant rounded-xl overflow-hidden hover:shadow-[0px_4px_12px_rgba(26,43,60,0.08)] transition-shadow duration-200 flex flex-col relative">
<div class="absolute left-0 top-0 bottom-0 w-2 bg-secondary"></div>
<div class="p-stack-lg flex-grow pl-6">
<div class="flex justify-between items-start mb-stack-md">
<div>
<span class="font-label-md text-label-md text-on-surface-variant tracking-wider uppercase">#ORD-2023-8950</span>
<h2 class="font-headline-sm text-headline-sm text-on-surface mt-1">Downtown Branch Upgrade</h2>
</div>
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full font-label-md text-label-md bg-surface-variant text-on-surface border border-outline-variant">
                            procurement
                        </span>
</div>
<div class="grid grid-cols-2 gap-stack-md mb-stack-lg">
<div class="flex flex-col gap-1">
<span class="font-body-sm text-body-sm text-on-surface-variant">Manager</span>
<span class="font-body-md text-body-md text-on-surface">Elena Rodriguez</span>
</div>
<div class="flex flex-col gap-1">
<span class="font-body-sm text-body-sm text-on-surface-variant">Target Date</span>
<span class="font-body-md text-body-md text-on-surface">Nov 15, 2023</span>
</div>
</div>
<!-- Progress -->
<div class="mt-auto">
<div class="h-1.5 w-full bg-surface-variant rounded-full overflow-hidden">
<div class="h-full bg-secondary w-1/4"></div>
</div>
<p class="font-body-sm text-body-sm text-on-surface-variant mt-2 text-right">Step 1 of 4</p>
</div>
</div>
</div>
<!-- Card 4: Early Stage -->
<div class="lg:col-span-6 bg-surface-container-lowest border border-outline-variant rounded-xl overflow-hidden hover:shadow-[0px_4px_12px_rgba(26,43,60,0.08)] transition-shadow duration-200 flex flex-col relative">
<div class="absolute left-0 top-0 bottom-0 w-2 bg-[#F59E0B]"></div>
<div class="p-stack-lg flex-grow pl-6">
<div class="flex justify-between items-start mb-stack-md">
<div>
<span class="font-label-md text-label-md text-on-surface-variant tracking-wider uppercase">#ORD-2023-8951</span>
<h2 class="font-headline-sm text-headline-sm text-on-surface mt-1">Retail Kiosk Deployment</h2>
</div>
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full font-label-md text-label-md bg-[#FFFBEB] text-[#B45309] border border-[#FDE68A]">
                            site_prep
                        </span>
</div>
<div class="grid grid-cols-2 gap-stack-md mb-stack-lg">
<div class="flex flex-col gap-1">
<span class="font-body-sm text-body-sm text-on-surface-variant">Manager</span>
<span class="font-body-md text-body-md text-on-surface">David Kim</span>
</div>
<div class="flex flex-col gap-1">
<span class="font-body-sm text-body-sm text-on-surface-variant">Location</span>
<span class="font-body-md text-body-md text-on-surface line-clamp-1">Mall of America, MN</span>
</div>
</div>
<!-- Progress -->
<div class="mt-auto">
<div class="h-1.5 w-full bg-surface-variant rounded-full overflow-hidden flex">
<div class="h-full bg-[#F59E0B] w-1/4 border-r border-surface-container-lowest"></div>
<div class="h-full bg-[#F59E0B] w-1/4 relative overflow-hidden">
<div class="absolute inset-0 bg-white/20 animate-pulse"></div>
</div>
</div>
<p class="font-body-sm text-body-sm text-on-surface-variant mt-2 text-right">Step 2 of 4</p>
</div>
</div>
</div>
</div>
</main>
<!-- BottomNavBar (Mobile Only) -->
<nav class="md:hidden bg-surface dark:bg-inverse-surface border-t border-outline-variant dark:border-outline docked full-width bottom-0 fixed left-0 w-full z-50 flex justify-around items-center px-2 py-3 pb-safe">
<a class="flex flex-col items-center justify-center text-on-surface-variant dark:text-surface-variant px-4 py-1 hover:bg-surface-container-high dark:hover:bg-surface-container-highest transition-colors" href="#">
<span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 0;">home</span>
<span class="font-label-md text-label-md mt-1">Home</span>
</a>
<a class="flex flex-col items-center justify-center text-on-surface-variant dark:text-surface-variant px-4 py-1 hover:bg-surface-container-high dark:hover:bg-surface-container-highest transition-colors" href="#">
<span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 0;">contacts</span>
<span class="font-label-md text-label-md mt-1">CRM</span>
</a>
<a class="flex flex-col items-center justify-center text-on-surface-variant dark:text-surface-variant px-4 py-1 hover:bg-surface-container-high dark:hover:bg-surface-container-highest transition-colors" href="#">
<span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 0;">local_shipping</span>
<span class="font-label-md text-label-md mt-1">Logistics</span>
</a>
<a class="flex flex-col items-center justify-center bg-primary-container dark:bg-primary-container text-on-primary-container dark:text-on-primary-container rounded-2xl px-4 py-1 Active: scale-90 duration-200 ease-in-out" href="#">
<span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1;">task_alt</span>
<span class="font-label-md text-label-md mt-1">Execution</span>
</a>
<a class="flex flex-col items-center justify-center text-on-surface-variant dark:text-surface-variant px-4 py-1 hover:bg-surface-container-high dark:hover:bg-surface-container-highest transition-colors" href="#">
<span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 0;">groups</span>
<span class="font-label-md text-label-md mt-1">HR</span>
</a>
</nav>
</body></html>
