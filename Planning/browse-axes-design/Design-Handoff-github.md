# GitHub source

repo: joshbotts/FRUS-Explorer
branch: v2

## Last sync
date: 2026-08-22T17:55:20Z

### Updated in this project
- Recreated current iOS Browse tab root, subseries level, and macOS Corpus Browser window as baseline mockups
- Built Browse Axes design-proposal canvas for issue #1051 (Q-9 directions, Q-7 variants, per-axis screens, R-1 component spec)

## Screen map
| Project screen | Repo files |
|---|---|
| Browse Axes Proposals.dc.html — 1a baseline iPhone root | FRUSExplorer/Browser/CorpusView.swift, FRUSExplorer/Browser/BrowserViewModel.swift, FRUSExplorer/App/MainTabView.swift |
| Browse Axes Proposals.dc.html — 1a baseline Mac window | FRUSExplorer/App/MacCorpusBrowserWindow.swift |
| Browse Axes Proposals.dc.html — volume rows / badges | FRUSExplorer/Browser/SubseriesView.swift (VolumeRowLabel), FRUSExplorer/App/MacCorpusBrowserWindow.swift (SubseriesVolumeListView) |
| Browse Axes Proposals.dc.html — index-level template | FRUSExplorer/Browser/SubjectIndexView.swift |
| Browse Axes Proposals.dc.html — breadcrumbs | FRUSExplorer/Browser/BrowserBreadcrumbBar.swift |
| Browse Axes Proposals.dc.html — iPad two-pane | FRUSExplorer/Browser/BrowseTwoPaneMetrics.swift |
| Browse Axes Proposals.dc.html — volume level (Q-5) | FRUSExplorer/Browser/VolumeView.swift |
