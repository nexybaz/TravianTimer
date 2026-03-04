import SwiftUI

// MARK: - Guides Tool (Uebersicht)

struct GuidesToolView: View {

    @State private var favorites = FavoritesStore.shared

    private let schnellsiedelFavId = FavoriteToolItem.guideSchnellsiedeln.rawValue

    private let questsFavId = FavoriteToolItem.guideQuests.rawValue

    var body: some View {
        List {
            NavigationLink {
                QuestsGuideView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aufgaben (Quests)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Alle Quests mit Belohnungen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "text.book.closed.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.indigo.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .contextMenu {
                Button {
                    withAnimation { favorites.toggle(questsFavId) }
                } label: {
                    Label(
                        favorites.isFavorite(questsFavId) ? "Aus Favoriten entfernen" : "An Tools anheften",
                        systemImage: favorites.isFavorite(questsFavId) ? "pin.slash" : "pin.fill"
                    )
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    withAnimation { favorites.toggle(questsFavId) }
                } label: {
                    Label(
                        favorites.isFavorite(questsFavId) ? "Lösen" : "Anheften",
                        systemImage: favorites.isFavorite(questsFavId) ? "pin.slash" : "pin.fill"
                    )
                }
                .tint(.orange)
            }

            NavigationLink {
                SchnellsiedelGuideView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Schnellsiedeln")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Schnellsiedel-Guide v1.1 -RE-")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "hare.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.green.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .contextMenu {
                Button {
                    withAnimation { favorites.toggle(schnellsiedelFavId) }
                } label: {
                    Label(
                        favorites.isFavorite(schnellsiedelFavId) ? "Aus Favoriten entfernen" : "An Tools anheften",
                        systemImage: favorites.isFavorite(schnellsiedelFavId) ? "pin.slash" : "pin.fill"
                    )
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    withAnimation { favorites.toggle(schnellsiedelFavId) }
                } label: {
                    Label(
                        favorites.isFavorite(schnellsiedelFavId) ? "Lösen" : "Anheften",
                        systemImage: favorites.isFavorite(schnellsiedelFavId) ? "pin.slash" : "pin.fill"
                    )
                }
                .tint(.orange)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Guides")
        .navigationBarTitleDisplayMode(.inline)
    }
}
