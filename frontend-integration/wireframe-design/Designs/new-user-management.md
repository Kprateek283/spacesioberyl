<!DOCTYPE html>

<html lang="en"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>IAM User Management Dashboard</title>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600&amp;family=Inter:wght@400;600&amp;display=swap" rel="stylesheet"/>
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
                        "headline-sm": ["20px", { "lineHeight": "28px", "fontWeight": "500" }],
                        "label-md": ["12px", { "lineHeight": "16px", "letterSpacing": "0.05em", "fontWeight": "600" }],
                        "display-lg": ["48px", { "lineHeight": "56px", "letterSpacing": "-0.02em", "fontWeight": "600" }],
                        "headline-lg-mobile": ["28px", { "lineHeight": "36px", "fontWeight": "600" }],
                        "headline-md": ["24px", { "lineHeight": "32px", "fontWeight": "500" }],
                        "body-md": ["16px", { "lineHeight": "24px", "fontWeight": "400" }],
                        "label-lg": ["14px", { "lineHeight": "20px", "letterSpacing": "0.02em", "fontWeight": "600" }],
                        "body-sm": ["14px", { "lineHeight": "20px", "fontWeight": "400" }],
                        "headline-lg": ["32px", { "lineHeight": "40px", "letterSpacing": "-0.01em", "fontWeight": "600" }],
                        "body-lg": ["18px", { "lineHeight": "28px", "fontWeight": "400" }]
                    }
                }
            }
        }
    </script>
<style>
    body {
      min-height: max(884px, 100dvh);
    }
  </style>
  </head>
<body class="bg-background text-on-background min-h-screen flex flex-col font-body-md antialiased pb-24 md:pb-0">
<!-- TopAppBar -->
<header class="flex justify-between items-center w-full px-container-padding-mobile md:px-container-padding-desktop h-16 bg-surface border-b border-outline-variant sticky top-0 z-40">
<div class="flex items-center gap-gutter">
<span class="font-headline-md text-headline-md font-semibold text-primary">Enterprise Suite</span>
<!-- Desktop Navigation Cluster -->
<nav class="hidden md:flex items-center gap-stack-md ml-stack-lg">
<button class="text-on-surface-variant hover:bg-surface-container-low transition-colors px-3 py-2 rounded-lg flex items-center gap-2">
<span class="material-symbols-outlined text-[20px]">home</span>
<span class="font-label-lg text-label-lg">Home</span>
</button>
<button class="text-on-surface-variant hover:bg-surface-container-low transition-colors px-3 py-2 rounded-lg flex items-center gap-2">
<span class="material-symbols-outlined text-[20px]">contacts</span>
<span class="font-label-lg text-label-lg">CRM</span>
</button>
<button class="text-on-surface-variant hover:bg-surface-container-low transition-colors px-3 py-2 rounded-lg flex items-center gap-2">
<span class="material-symbols-outlined text-[20px]">local_shipping</span>
<span class="font-label-lg text-label-lg">Logistics</span>
</button>
<button class="text-on-surface-variant hover:bg-surface-container-low transition-colors px-3 py-2 rounded-lg flex items-center gap-2">
<span class="material-symbols-outlined text-[20px]">task_alt</span>
<span class="font-label-lg text-label-lg">Execution</span>
</button>
<button class="text-primary font-bold hover:bg-surface-container-low transition-colors px-3 py-2 rounded-lg flex items-center gap-2 bg-surface-container-low">
<span class="material-symbols-outlined text-[20px]">groups</span>
<span class="font-label-lg text-label-lg">HR</span>
</button>
</nav>
</div>
<div class="flex items-center gap-stack-md">
<button class="w-10 h-10 rounded-full flex items-center justify-center text-on-surface-variant hover:bg-surface-container-low transition-colors">
<span class="material-symbols-outlined">notifications</span>
</button>
<div class="w-8 h-8 rounded-full bg-surface-variant overflow-hidden border border-outline-variant flex items-center justify-center">
<img alt="User Avatar" class="w-full h-full object-cover" data-alt="A professional headshot of a corporate executive in a modern, brightly lit office environment. The lighting is soft and even, highlighting a crisp, high-contrast aesthetic typical of contemporary light-mode enterprise interfaces. The color palette relies on neutral greys and subtle warm skin tones, projecting authority and approachability." src="https://lh3.googleusercontent.com/aida-public/AB6AXuC2dAIqaUicT-KMJXK8e86GI8pxvKksZar2tv4cdLjPgiyIJ2-LXLegI8VQh1iso6E_yDTAyNCOMJIPfWPTGDsW8zeX8InenGt3lUnKiSEQxPTqSVhkPrZs-n2X0Gjg-ocnUehUbAvhAIwRDuHsz0N7B-M0W5MPEyhlFAqDcQrCpZ7oT7a5HMCXjHwud0Xd0Kth9B-t6ZbeltjGDnh2CQ_zNWkmQyhC0PzQij1MwEHshen8ZyV45azALe6A-j6mX2ozCfHvc95qTg"/>
</div>
</div>
</header>
<!-- Main Content Canvas -->
<main class="flex-1 w-full max-w-[1440px] mx-auto px-container-padding-mobile md:px-container-padding-desktop py-stack-lg flex flex-col gap-stack-lg">
<!-- Header & Actions -->
<div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-stack-md">
<div>
<h1 class="font-headline-lg text-headline-lg text-on-surface">IAM User Management</h1>
<p class="font-body-md text-body-md text-on-surface-variant mt-1">Manage system access, roles, and departmental assignments.</p>
</div>
<div class="w-full md:w-auto relative group">
<span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-outline group-focus-within:text-primary transition-colors">search</span>
<input class="w-full md:w-[320px] pl-10 pr-4 py-2 bg-surface-container-lowest border border-outline rounded-lg font-body-sm text-body-sm text-on-surface focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all placeholder:text-outline-variant" placeholder="Search by name or email..." type="text"/>
</div>
</div>
<!-- Dashboard Stats (Bento-lite intro) -->
<div class="grid grid-cols-1 md:grid-cols-3 gap-gutter">
<div class="bg-surface-container-lowest border border-outline-variant rounded-xl p-stack-md shadow-[0px_4px_12px_rgba(26,43,60,0.02)] flex items-center gap-4">
<div class="w-12 h-12 rounded-full bg-primary-container text-on-primary-container flex items-center justify-center">
<span class="material-symbols-outlined">group</span>
</div>
<div>
<p class="font-label-md text-label-md text-on-surface-variant uppercase tracking-wider">Total Users</p>
<p class="font-headline-md text-headline-md text-on-surface">1,248</p>
</div>
</div>
<div class="bg-surface-container-lowest border border-outline-variant rounded-xl p-stack-md shadow-[0px_4px_12px_rgba(26,43,60,0.02)] flex items-center gap-4">
<div class="w-12 h-12 rounded-full bg-secondary-container text-on-secondary-container flex items-center justify-center">
<span class="material-symbols-outlined">verified_user</span>
</div>
<div>
<p class="font-label-md text-label-md text-on-surface-variant uppercase tracking-wider">Active Accounts</p>
<p class="font-headline-md text-headline-md text-on-surface">1,192</p>
</div>
</div>
<div class="bg-surface-container-lowest border border-outline-variant rounded-xl p-stack-md shadow-[0px_4px_12px_rgba(26,43,60,0.02)] flex items-center gap-4">
<div class="w-12 h-12 rounded-full bg-error-container text-on-error-container flex items-center justify-center">
<span class="material-symbols-outlined">gpp_bad</span>
</div>
<div>
<p class="font-label-md text-label-md text-on-surface-variant uppercase tracking-wider">Suspended</p>
<p class="font-headline-md text-headline-md text-on-surface">56</p>
</div>
</div>
</div>
<!-- Data Table Section (Level 1 Elevation) -->
<div class="bg-surface-container-lowest border border-outline-variant rounded-xl overflow-hidden flex flex-col shadow-[0px_4px_12px_rgba(26,43,60,0.02)]">
<div class="overflow-x-auto">
<table class="w-full text-left border-collapse whitespace-nowrap">
<thead>
<tr class="border-b-2 border-outline-variant bg-surface-container-lowest">
<th class="font-label-lg text-label-lg text-on-surface-variant p-stack-md font-semibold">User</th>
<th class="font-label-lg text-label-lg text-on-surface-variant p-stack-md font-semibold">Email Address</th>
<th class="font-label-lg text-label-lg text-on-surface-variant p-stack-md font-semibold">System Role</th>
<th class="font-label-lg text-label-lg text-on-surface-variant p-stack-md font-semibold">Department</th>
<th class="font-label-lg text-label-lg text-on-surface-variant p-stack-md font-semibold">Status</th>
<th class="font-label-lg text-label-lg text-on-surface-variant p-stack-md font-semibold text-right">Actions</th>
</tr>
</thead>
<tbody class="divide-y divide-outline-variant">
<!-- Row 1 -->
<tr class="hover:bg-surface-container-low transition-colors group">
<td class="p-stack-md">
<div class="flex items-center gap-3">
<div class="w-8 h-8 rounded-full bg-surface-variant overflow-hidden border border-outline-variant">
<img alt="Sarah Jenkins Avatar" class="w-full h-full object-cover" data-alt="A brightly lit, professional portrait of a woman in corporate attire against a clean, minimal white background. The image has a crisp, modern aesthetic suitable for a high-end enterprise application, utilizing a restricted palette of subtle greys and warm natural tones." src="https://lh3.googleusercontent.com/aida-public/AB6AXuACgBV__opSB71FFO45uz7uuSIJj2_mSmgNM8Shpc9cLgrI-SKDTLbXJQ-Yd1eTJPNpr6sQLoxyV68szxfby7s-XBXTc_EieOzGkKdb5p_BO-bzsJX5573aINxxVY3-kPrypSKqCAnBQw-o5ilOb-1d7MKCjZhYX6uVNgr-FGuhCQBjGC3HXBYXHNPlYf8nj4N37ZcmurMAuFHyY9xT2BZFTKyPhH8ZlfTQGFO64sx7cbJKBovX_6_N7zpdHad8q-lopnz0grqetA"/>
</div>
<span class="font-body-md text-body-md text-on-surface font-medium">Sarah Jenkins</span>
</div>
</td>
<td class="p-stack-md font-body-sm text-body-sm text-on-surface-variant">s.jenkins@enterprise.inc</td>
<td class="p-stack-md">
<span class="inline-flex items-center px-2 py-1 rounded-md font-label-md text-label-md bg-primary-container text-on-primary-container border border-primary-fixed-dim">
                                    Admin
                                </span>
</td>
<td class="p-stack-md font-body-sm text-body-sm text-on-surface">Operations</td>
<td class="p-stack-md">
<div class="flex items-center gap-2">
<div class="w-2 h-2 rounded-full bg-primary"></div>
<span class="font-body-sm text-body-sm text-on-surface">Active</span>
</div>
</td>
<td class="p-stack-md text-right">
<div class="flex justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
<button class="p-1 rounded text-secondary hover:bg-surface-variant transition-colors" title="Edit Role">
<span class="material-symbols-outlined text-[20px]">edit</span>
</button>
<button class="p-1 rounded text-error hover:bg-error-container transition-colors" title="Deactivate">
<span class="material-symbols-outlined text-[20px]">person_off</span>
</button>
</div>
</td>
</tr>
<!-- Row 2 -->
<tr class="hover:bg-surface-container-low transition-colors group">
<td class="p-stack-md">
<div class="flex items-center gap-3">
<div class="w-8 h-8 rounded-full bg-surface-variant overflow-hidden border border-outline-variant flex items-center justify-center text-on-surface-variant font-label-md">
                                        MR
                                    </div>
<span class="font-body-md text-body-md text-on-surface font-medium">Marcus Rodriguez</span>
</div>
</td>
<td class="p-stack-md font-body-sm text-body-sm text-on-surface-variant">m.rodriguez@enterprise.inc</td>
<td class="p-stack-md">
<span class="inline-flex items-center px-2 py-1 rounded-md font-label-md text-label-md bg-surface-variant text-on-surface-variant border border-outline-variant">
                                    Viewer
                                </span>
</td>
<td class="p-stack-md font-body-sm text-body-sm text-on-surface">Logistics</td>
<td class="p-stack-md">
<div class="flex items-center gap-2">
<div class="w-2 h-2 rounded-full bg-primary"></div>
<span class="font-body-sm text-body-sm text-on-surface">Active</span>
</div>
</td>
<td class="p-stack-md text-right">
<div class="flex justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
<button class="p-1 rounded text-secondary hover:bg-surface-variant transition-colors" title="Edit Role">
<span class="material-symbols-outlined text-[20px]">edit</span>
</button>
<button class="p-1 rounded text-error hover:bg-error-container transition-colors" title="Deactivate">
<span class="material-symbols-outlined text-[20px]">person_off</span>
</button>
</div>
</td>
</tr>
<!-- Row 3 -->
<tr class="hover:bg-surface-container-low transition-colors group">
<td class="p-stack-md">
<div class="flex items-center gap-3">
<div class="w-8 h-8 rounded-full bg-surface-variant overflow-hidden border border-outline-variant">
<img alt="David Chen Avatar" class="w-full h-full object-cover" data-alt="A clean, highly focused headshot of a male professional wearing a dark blazer over a crisp shirt. The background is a stark, minimal off-white, emphasizing a corporate modern aesthetic. The lighting is bright and even, casting almost no shadows, aligning perfectly with an enterprise light-mode UI design." src="https://lh3.googleusercontent.com/aida-public/AB6AXuC9mffPHTf25Bu1MBUdnPOaeV1QfFygHtUY8ykw44ky3p6jWDRrk0dpzFIcBunAqa8xlL74aMHMazwybrTi-qYAwxqU5S_-6L_Fi_oZVQLA58V-P3i3an8uI0P1cKy8XPAGqQRqm3nWfco0aJ8cVttJENhGDuS4qCoUhsD9xcjH1vZZzgRvkOa_J8NNmqySG6c9Wn1uu8wf3pTlZx-QS11dZue1p-uFLdhUXKK2WtWcMSxwP3UiPVoLKinwwNmBOZ22fP6LcDGYWw"/>
</div>
<span class="font-body-md text-body-md text-on-surface font-medium">David Chen</span>
</div>
</td>
<td class="p-stack-md font-body-sm text-body-sm text-on-surface-variant">d.chen@enterprise.inc</td>
<td class="p-stack-md">
<span class="inline-flex items-center px-2 py-1 rounded-md font-label-md text-label-md bg-secondary-container text-on-secondary-container border border-secondary-fixed-dim">
                                    Editor
                                </span>
</td>
<td class="p-stack-md font-body-sm text-body-sm text-on-surface">Human Resources</td>
<td class="p-stack-md">
<div class="flex items-center gap-2">
<div class="w-2 h-2 rounded-full bg-outline"></div>
<span class="font-body-sm text-body-sm text-on-surface-variant">Suspended</span>
</div>
</td>
<td class="p-stack-md text-right">
<div class="flex justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
<button class="p-1 rounded text-secondary hover:bg-surface-variant transition-colors" title="Edit Role">
<span class="material-symbols-outlined text-[20px]">edit</span>
</button>
<button class="p-1 rounded text-error hover:bg-error-container transition-colors" title="Deactivate">
<span class="material-symbols-outlined text-[20px]">person_off</span>
</button>
</div>
</td>
</tr>
</tbody>
</table>
</div>
<!-- Table Footer / Pagination -->
<div class="bg-surface border-t border-outline-variant p-stack-sm flex justify-between items-center px-stack-md">
<span class="font-body-sm text-body-sm text-on-surface-variant">Showing 1-3 of 1,248</span>
<div class="flex gap-2">
<button class="px-3 py-1 border border-outline-variant rounded text-on-surface-variant font-label-md hover:bg-surface-container-low transition-colors disabled:opacity-50" disabled="">Prev</button>
<button class="px-3 py-1 border border-outline-variant rounded text-on-surface-variant font-label-md hover:bg-surface-container-low transition-colors">Next</button>
</div>
</div>
</div>
</main>
<!-- Floating Action Button (FAB) -->
<button class="fixed bottom-24 md:bottom-stack-lg right-container-padding-mobile md:right-container-padding-desktop bg-primary text-on-primary w-14 h-14 rounded-2xl flex items-center justify-center shadow-[0px_12px_24px_rgba(26,43,60,0.15)] hover:bg-surface-tint hover:-translate-y-1 transition-all z-50 group" title="Create New User">
<span class="material-symbols-outlined text-[24px]">add</span>
</button>
<!-- BottomNavBar (Mobile Only) -->
<nav class="fixed bottom-0 left-0 w-full z-50 flex justify-around items-center px-2 py-3 pb-safe bg-surface border-t border-outline-variant md:hidden">
<div class="flex flex-col items-center justify-center text-on-surface-variant px-4 py-1">
<span class="material-symbols-outlined">home</span>
<span class="font-label-md text-label-md mt-1">Home</span>
</div>
<div class="flex flex-col items-center justify-center text-on-surface-variant px-4 py-1">
<span class="material-symbols-outlined">contacts</span>
<span class="font-label-md text-label-md mt-1">CRM</span>
</div>
<div class="flex flex-col items-center justify-center text-on-surface-variant px-4 py-1">
<span class="material-symbols-outlined">local_shipping</span>
<span class="font-label-md text-label-md mt-1">Logistics</span>
</div>
<div class="flex flex-col items-center justify-center text-on-surface-variant px-4 py-1">
<span class="material-symbols-outlined">task_alt</span>
<span class="font-label-md text-label-md mt-1">Execution</span>
</div>
<div class="flex flex-col items-center justify-center bg-primary-container text-on-primary-container rounded-2xl px-4 py-1 scale-90 transition-all duration-200 ease-in-out">
<span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1;">groups</span>
<span class="font-label-md text-label-md mt-1">HR</span>
</div>
</nav>
</body></html>
