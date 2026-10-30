import CoreImage
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: qr <text> <out.png>\n".data(using: .utf8)!)
    exit(2)
}
guard let data = args[1].data(using: .utf8),
      let filter = CIFilter(name: "CIQRCodeGenerator") else {
    exit(1)
}
filter.setValue(data, forKey: "inputMessage")
filter.setValue("M", forKey: "inputCorrectionLevel")
guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)) else {
    exit(1)
}
let rep = NSBitmapImageRep(ciImage: output)
guard let png = rep.representation(using: .png, properties: [:]) else {
    exit(1)
}
try png.write(to: URL(fileURLWithPath: args[2]))
