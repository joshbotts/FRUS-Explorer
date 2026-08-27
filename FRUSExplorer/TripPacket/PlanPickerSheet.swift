// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import SwiftData

// MARK: - PlanPickerRequest

/// An `Identifiable` presentation request for ``PlanPickerSheet`` — hosts resolve their
/// documents first (a smart collection's membership is async), then present on the item.
struct PlanPickerRequest: Identifiable {
    let id = UUID()
    let documents: [(volumeId: String, documentId: String)]
    let includeSource: Bool
    let includeExternalRefs: Bool
    let basis: String
    var suggestedName: String? = nil
}

// MARK: - PlanPickerSheet

/// Adds a set of seed documents to an existing Archive Visit, or creates a new one — the 1e
/// picker, cloning `CollectionPickerSheet`'s shape (searchable list, New row, dedupe guard,
/// checkmark + auto-dismiss, medium/large detents on iOS, plain `VStack` body on macOS).
///
/// The picker carries a **preset contribution scope** and a **basis string** (the blue banner):
/// which of the two claims the seeds contribute, and where the add came from — so the researcher
/// approves exactly what a surface is about to write. The write itself goes through
/// `ArchiveVisitPlan.addSeeds`, the one path every add flow shares: flags UNION on an existing
/// seed (adding references never switches off a source contribution another surface added),
/// derived ids dedupe by construction.
///
/// Version history:
///   1.0 — Archive Visits Phase 3: initial implementation
struct PlanPickerSheet: View {

    /// Builds the picker from a presentation request.
    init(request: PlanPickerRequest, onAdded: ((ArchiveVisitPlan) -> Void)? = nil) {
        self.documents = request.documents
        self.includeSource = request.includeSource
        self.includeExternalRefs = request.includeExternalRefs
        self.basis = request.basis
        self.suggestedName = request.suggestedName
        self.onAdded = onAdded
    }

    init(documents: [(volumeId: String, documentId: String)],
         includeSource: Bool, includeExternalRefs: Bool, basis: String,
         suggestedName: String? = nil, onAdded: ((ArchiveVisitPlan) -> Void)? = nil) {
        self.documents = documents
        self.includeSource = includeSource
        self.includeExternalRefs = includeExternalRefs
        self.basis = basis
        self.suggestedName = suggestedName
        self.onAdded = onAdded
    }

    /// The documents being seeded, as `(volumeId, documentId)`.
    let documents: [(volumeId: String, documentId: String)]
    /// The preset contribution scope — which claims these seeds feed.
    let includeSource: Bool
    let includeExternalRefs: Bool
    /// How the seed was made ("From Source Explorer", "the 12 neighbors shown") — the banner.
    let basis: String
    /// The auto-name for a plan created from this add (§4a: seeded creation auto-names from
    /// its seed — the collection's name, the unit's label). `nil` creates an untitled plan.
    var suggestedName: String? = nil
    /// Called after a successful add, with the receiving plan — lets a host offer "open".
    var onAdded: ((ArchiveVisitPlan) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ArchiveVisitPlan.lastModified, order: .reverse)
    private var plans: [ArchiveVisitPlan]

    @State private var searchText = ""
    @State private var addedPlanId: UUID?

    private var filtered: [ArchiveVisitPlan] {
        guard !searchText.isEmpty else { return plans }
        return plans.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    private var pickerTitle: String {
        String(localized: "archiveVisit.picker.title", defaultValue: "Add to Archive Visit")
    }

    /// The banner: what is being added, under which claims, from where.
    private var bannerText: String {
        let contribution: String
        switch (includeSource, includeExternalRefs) {
        case (true, true):
            contribution = String(format: String(
                localized: "archiveVisit.picker.adding.both %lld",
                defaultValue: "Adding %lld documents: archival sources + unprinted references"),
                Int64(documents.count))
        case (true, false):
            contribution = String(format: String(
                localized: "archiveVisit.picker.adding.source %lld",
                defaultValue: "Adding %lld documents: archival sources"),
                Int64(documents.count))
        default:
            contribution = String(format: String(
                localized: "archiveVisit.picker.adding.refs %lld",
                defaultValue: "Adding %lld documents: unprinted references"),
                Int64(documents.count))
        }
        return "\(contribution) — \(basis)"
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - Shared pieces

    private var banner: some View {
        Text(bannerText)
            .font(.caption)
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// One plan row: name + seed count + an added checkmark. The count is the SEED count —
    /// honest and cheap; a target count would need a per-row derivation against the index.
    private func planRow(_ plan: ArchiveVisitPlan) -> some View {
        Button {
            add(to: plan)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    let count = (plan.documents ?? []).count
                    Text(String(format: String(localized: "archiveVisit.picker.docCount %lld",
                                               defaultValue: "%lld documents"), Int64(count)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if addedPlanId == plan.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel(String(localized: "archiveVisit.picker.added.a11y",
                                                   defaultValue: "Added"))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var newPlanRow: some View {
        Button {
            createAndAdd()
        } label: {
            Label(String(localized: "archiveVisit.picker.new",
                         defaultValue: "New Archive Visit"),
                  systemImage: "plus.circle")
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }

    // MARK: - macOS body

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text(pickerTitle)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)

            banner
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            if !plans.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                    TextField(String(localized: "archiveVisit.picker.search.placeholder",
                                     defaultValue: "Search Archive Visits…"), text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            Divider()

            List {
                ForEach(filtered) { plan in planRow(plan) }
                newPlanRow
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 400, minHeight: 360)
    }
    #endif

    // MARK: - iOS body

    #if os(iOS)
    private var iOSBody: some View {
        NavigationStack {
            List {
                Section {
                    banner
                }
                Section {
                    ForEach(filtered) { plan in planRow(plan) }
                    newPlanRow
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText,
                        prompt: String(localized: "archiveVisit.picker.search.prompt",
                                       defaultValue: "Search Archive Visits"))
            .navigationTitle(pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancel")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    #endif

    // MARK: - Add actions

    private func add(to plan: ArchiveVisitPlan) {
        plan.addSeeds(documents, includeSource: includeSource,
                      includeExternalRefs: includeExternalRefs, in: modelContext)
        try? modelContext.save()
        addedPlanId = plan.id
        onAdded?(plan)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
    }

    private func createAndAdd() {
        let plan = ArchiveVisitPlan(name: suggestedName ?? "")
        modelContext.insert(plan)
        add(to: plan)
    }
}
