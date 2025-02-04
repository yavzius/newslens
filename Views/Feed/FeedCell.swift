import SwiftUI

struct FeedCell: View {
    let article: Article
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                if let imageName = article.imageName, let uiImage = UIImage(named: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    if let category = article.category {
                        Text(category.uppercased())
                            .font(.caption)
                            .foregroundColor(.red)
                            .bold()
                    }
                     
                    Text(article.headline)
                        .font(.title2)
                        .foregroundColor(.white)
                        .bold()
                        .lineLimit(3)
                    
                    if let subheadline = article.subheadline {
                        Text(subheadline)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
                .frame(maxWidth: geometry.size.width)
            }
        }
    }
}



struct FeedCell_Previews: PreviewProvider {
    static var previews: some View {
        FeedCell(article: mockArticles.first!)
            .previewInterfaceOrientation(.portrait)
    }
}
