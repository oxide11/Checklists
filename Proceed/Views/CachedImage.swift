import SwiftUI

/// A view that wraps UIImage(data:) decoding in its own view identity,
/// preventing redundant decoding when the parent view rebuilds.
/// SwiftUI will only re-evaluate this view's body when `data` changes.
struct CachedImage: View {
    let data: Data

    var body: some View {
        if let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
        }
    }
}
