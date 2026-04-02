## 2025-05-22 - Context-Aware Empty States and Accessibility Semantics

**Learning:** When a user's search returns no results, displaying a generic "No data" message is confusing. Differentiating between "No data available" and "No results matching your criteria" provides better guidance (e.g., suggesting to adjust the query). Additionally, providing explicit `Semantics` to critical toggle buttons ensures screen reader users understand the button's action beyond its visual icon or current text label.

**Action:** Always check `_searchQuery.isNotEmpty` (or equivalent) when building empty states and provide a specific "No results found" UI. Wrap key action buttons in `Semantics` widgets with descriptive labels and hints.
