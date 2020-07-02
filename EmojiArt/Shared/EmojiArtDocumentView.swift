//
//  EmojiArtDocumentView.swift
//  Shared
//
//  Created by Louis Tsai on 7/2/20.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    var body: some View {
        VStack {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(EmojiArtDocument.palette.map { String($0) }, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 40))
                            .onDrag { return NSItemProvider(object: emoji as NSString) }
                            
                    }
                }
            }
            .padding(.horizontal)
            GeometryReader { geometry in
                ZStack {
                    Color.white
                        .overlay(
                            Group {
                                if document.backgroundImage != nil {
                                    Image(uiImage: document.backgroundImage!)
                                }
                            }
                        )
                        .edgesIgnoringSafeArea(.bottom)
                        .onDrop(of: ["public.image", "public.text"], isTargeted: nil) { providers, location in
                            var location = geometry.convert(location, from: .global)
                            location = CGPoint(
                                x: location.x - geometry.size.width / 2,
                                y: location.y - geometry.size.height / 2
                            )
                            return self.drop(providers, at: location)

                        }
                    ForEach(document.emojis) { emoji in
                        Text(emoji.text)
                            .font(font(for: emoji))
                            .position(position(for: emoji, in: geometry.size))
                    }
                }
            }
        }
    }
    
    private func font(for emoji: EmojiArt.Emoji) -> Font {
        Font.system(size: emoji.fontSize)
    }
    
    private func position(for emoji: EmojiArt.Emoji, in size: CGSize) -> CGPoint {
        CGPoint(x: emoji.location.x + size.width / 2, y: emoji.location.y + size.height / 2)
    }
    
    private func drop(_ providers: [NSItemProvider], at location: CGPoint) -> Bool {
        var found = providers.loadFirstObject(ofType: URL.self) { url in
            document.setBackgroundURL(url)
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                self.document.addEmoji(string, at: location, size: 40)
            }
        }
        return found
    }
}

extension String: Identifiable {
    public var id: String { return self }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}

class EmojiArtDocument: ObservableObject {
    static let palette: String = "🍎🍌🍊"
    
    @Published private var emojiArt = EmojiArt()
    
    @Published private(set) var backgroundImage: UIImage?
    
    var emojis: [EmojiArt.Emoji] { emojiArt.emojis }
    
    /// MARK: Intent(s)
    
    func addEmoji(_ emoji: String, at location: CGPoint, size: CGFloat) {
        emojiArt.addEmoji(
            emoji,
            x: Int(location.x),
            y: Int(location.y),
            size: Int(size)
        )
    }
    
    func moveEmoji(_ emoji: EmojiArt.Emoji, by offset: CGSize) {
        if let index = emojiArt.emojis.firstIndex(matching: emoji) {
            emojiArt.emojis[index].x += Int(offset.width)
            emojiArt.emojis[index].y += Int(offset.height)
        }
    }
    
    func scaleEmoji(_ emoji: EmojiArt.Emoji, by scale: CGFloat) {
        if let index = emojiArt.emojis.firstIndex(matching: emoji) {
            emojiArt.emojis[index].size = Int(
                (CGFloat(emojiArt.emojis[index].size) * scale)
                    .rounded(.toNearestOrEven)
            )
        }
    }
    
    func setBackgroundURL(_ url: URL?) {
        emojiArt.backgroundURL = url?.imageURL
        fetchBackgroundImageData()
    }
    
    private func fetchBackgroundImageData() {
        backgroundImage = nil
        if let url = emojiArt.backgroundURL {
            DispatchQueue.global(qos: .userInitiated).async {
                if let imageData = try? Data(contentsOf: url) {
                    DispatchQueue.main.async {
                        if url == self.emojiArt.backgroundURL {
                            self.backgroundImage = UIImage(data: imageData)
                        } else {
                            print("background image loaded but it's too late")
                        }
                    }
                }
            }
        }
    }
}

struct EmojiArt {
    var backgroundURL: URL?
    var emojis = [Emoji]()
    
    struct Emoji: Identifiable {
        let text: String
        var x: Int
        var y: Int
        var size: Int
        
        let id: Int
        
        fileprivate init(text: String, x: Int, y: Int, size: Int, id: Int) {
            self.text = text
            self.x = x
            self.y = y
            self.size = size
            self.id = id
        }
    }
    
    private var uniqueEmojiId = 0
    
    mutating func addEmoji (_ text: String, x: Int, y: Int, size: Int) {
        uniqueEmojiId += 1
        emojis.append(Emoji(text: text, x: x, y: y, size: size, id: uniqueEmojiId))
    }
}

extension Collection where Element: Identifiable {
    func firstIndex(matching element: Element) -> Self.Index? {
        firstIndex(where: { $0.id == element.id })
    }
    // note that contains(matching:) is different than contains()
    // this version uses the Identifiable-ness of its elements
    // to see whether a member of the Collection has the same identity
    func contains(matching element: Element) -> Bool {
        self.contains(where: { $0.id == element.id })
    }
}

extension Data {
    // just a simple converter from a Data to a String
    var utf8: String? { String(data: self, encoding: .utf8 ) }
}

extension URL {
    var imageURL: URL {
        // check to see if there is an embedded imgurl reference
        for query in query?.components(separatedBy: "&") ?? [] {
            let queryComponents = query.components(separatedBy: "=")
            if queryComponents.count == 2 {
                if queryComponents[0] == "imgurl", let url = URL(string: queryComponents[1].removingPercentEncoding ?? "") {
                    return url
                }
            }
        }
        // this snippet supports the demo in Lecture 14
        // see storeInFilesystem below
        if isFileURL {
            var url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            url = url?.appendingPathComponent(self.lastPathComponent)
            if url != nil {
                return url!
            }
        }
        return self.baseURL ?? self
    }
}

extension GeometryProxy {
    // converts from some other coordinate space to the proxy's own
    func convert(_ point: CGPoint, from coordinateSpace: CoordinateSpace) -> CGPoint {
        let frame = self.frame(in: coordinateSpace)
        return CGPoint(x: point.x-frame.origin.x, y: point.y-frame.origin.y)
    }
}

// simplifies the drag/drop portion of the demo
// you might be able to grok this
// but it does use a generic function
// and also is doing multithreaded stuff here
// and also is bridging to Objective-C-based API
// so kind of too much to talk about during lecture at this point in the game!

extension Array where Element == NSItemProvider {
    func loadObjects<T>(ofType theType: T.Type, firstOnly: Bool = false, using load: @escaping (T) -> Void) -> Bool where T: NSItemProviderReading {
        if let provider = self.first(where: { $0.canLoadObject(ofClass: theType) }) {
            provider.loadObject(ofClass: theType) { object, error in
                if let value = object as? T {
                    DispatchQueue.main.async {
                        load(value)
                    }
                }
            }
            return true
        }
        return false
    }
    func loadObjects<T>(ofType theType: T.Type, firstOnly: Bool = false, using load: @escaping (T) -> Void) -> Bool where T: _ObjectiveCBridgeable, T._ObjectiveCType: NSItemProviderReading {
        if let provider = self.first(where: { $0.canLoadObject(ofClass: theType) }) {
            let _ = provider.loadObject(ofClass: theType) { object, error in
                if let value = object {
                    DispatchQueue.main.async {
                        load(value)
                    }
                }
            }
            return true
        }
        return false
    }
    func loadFirstObject<T>(ofType theType: T.Type, using load: @escaping (T) -> Void) -> Bool where T: NSItemProviderReading {
        self.loadObjects(ofType: theType, firstOnly: true, using: load)
    }
    func loadFirstObject<T>(ofType theType: T.Type, using load: @escaping (T) -> Void) -> Bool where T: _ObjectiveCBridgeable, T._ObjectiveCType: NSItemProviderReading {
        self.loadObjects(ofType: theType, firstOnly: true, using: load)
    }
}

extension String {
    // returns ourself without any duplicate Characters
    // not very efficient, so only for use on small-ish Strings
    func uniqued() -> String {
        var uniqued = ""
        for ch in self {
            if !uniqued.contains(ch) {
                uniqued.append(ch)
            }
        }
        return uniqued
    }
}

// it cleans up our code to be able to do more "math" on points and sizes

extension CGPoint {
    static func -(lhs: Self, rhs: Self) -> CGSize {
        CGSize(width: lhs.x - rhs.x, height: lhs.y - rhs.y)
    }
    static func +(lhs: Self, rhs: CGSize) -> CGPoint {
        CGPoint(x: lhs.x + rhs.width, y: lhs.y + rhs.height)
    }
    static func -(lhs: Self, rhs: CGSize) -> CGPoint {
        CGPoint(x: lhs.x - rhs.width, y: lhs.y - rhs.height)
    }
    static func *(lhs: Self, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    static func /(lhs: Self, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }
}

extension CGSize {
    static func +(lhs: Self, rhs: Self) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
    static func -(lhs: Self, rhs: Self) -> CGSize {
        CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }
    static func *(lhs: Self, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }
    static func /(lhs: Self, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width/rhs, height: lhs.height/rhs)
    }
}

extension String
{
    // returns ourself but with numbers appended to the end
    // if necessary to make ourself unique with respect to those other Strings
    func uniqued<StringCollection>(withRespectTo otherStrings: StringCollection) -> String
        where StringCollection: Collection, StringCollection.Element == String {
        var unique = self
        while otherStrings.contains(unique) {
            unique = unique.incremented
        }
        return unique
    }
    
    // if a number is at the end of this String
    // this increments that number
    // otherwise, it appends the number 1
    var incremented: String  {
        let prefix = String(self.reversed().drop(while: { $0.isNumber }).reversed())
        if let number = Int(self.dropFirst(prefix.count)) {
            return "\(prefix)\(number+1)"
        } else {
            return "\(self) 1"
        }
    }
}

extension UIImage {
    // Lecture 14 support
    // stores ourself as jpeg in a file in the filesystem
    // in the Application Support directory in our sandbox
    // with the given name (or a unique name if no name provided)
    // and returns the URL to it
    // care must be taken if you hold on to a URL like this persistently
    // because your Application Support directory's URL
    // can change between instances of your application
    // (see some hackery in imageURL above to account for this)
    // if you wanted to hold on to a URL like this in the real world
    // (i.e. not in demo-ware)
    // you'd probably just hold onto the end part of the URL
    // (i.e. not including the Application Support directory's URL)
    // and then always prepend Application Support's URL upon use of the URL fragment
    // this function might also want to add a parameter for the compression quality
    // (currently it is best-quality compression)
    func storeInFilesystem(name: String = "\(Date().timeIntervalSince1970)") -> URL? {
        var url = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        url = url?.appendingPathComponent(name)
        if url != nil {
            do {
                try self.jpegData(compressionQuality: 1.0)?.write(to: url!)
            } catch {
                url = nil
            }
        }
        return url
    }
}

extension EmojiArt.Emoji {
    var fontSize: CGFloat { CGFloat(self.size) }
    var location: CGPoint { CGPoint(x: CGFloat(x), y: CGFloat(y)) }
}
