import Foundation
import SwiftData

@Model
final class MediaAttachment {
    var id: UUID = UUID()
    var mediaType: MediaType = MediaType.image
    var fileName: String = ""
    @Attribute(.externalStorage) var fileData: Data? = nil
    var caption: String? = nil

    var step: ChecklistStep? = nil

    init(
        mediaType: MediaType = .image,
        fileName: String = "",
        fileData: Data? = nil,
        caption: String? = nil
    ) {
        self.id = UUID()
        self.mediaType = mediaType
        self.fileName = fileName
        self.fileData = fileData
        self.caption = caption
    }
}
