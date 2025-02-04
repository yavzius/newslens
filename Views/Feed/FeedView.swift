import SwiftUI
import UIKit

struct FeedView: UIViewControllerRepresentable {
   typealias UIViewControllerType = FeedViewController
   
   func makeUIViewController(context: Context) -> FeedViewController {
       return FeedViewController()
   }
   
   func updateUIViewController(_ uiViewController: FeedViewController, context: Context) {}
   
   static func dismantleUIViewController(_ uiViewController: FeedViewController, coordinator: ()) {}
}

class FeedViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
   private var pageViewController: UIPageViewController!
   private var pages: [UIViewController] = []
   
   override func viewDidLoad() {
       super.viewDidLoad()
       view.insetsLayoutMarginsFromSafeArea = true
       setupPageViewController()
   }
   
   private func setupPageViewController() {
       pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .vertical)
       pageViewController.dataSource = self
       pageViewController.delegate = self
       pageViewController.view.insetsLayoutMarginsFromSafeArea = true
       
       mockArticles.forEach { article in
           let feedCell = FeedCellViewController(article: article)
           pages.append(feedCell)
       }
       
       if let firstPage = pages.first {
           pageViewController.setViewControllers([firstPage], direction: .forward, animated: true)
       }
       
       addChild(pageViewController)
       view.addSubview(pageViewController.view)
       pageViewController.view.frame = view.bounds
       pageViewController.didMove(toParent: self)
   }
   
   // MARK: - UIPageViewControllerDataSource
   func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
       guard let index = pages.firstIndex(of: viewController) else { return nil }
       return index > 0 ? pages[index - 1] : pages.last
   }
   
   func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
       guard let index = pages.firstIndex(of: viewController) else { return nil }
       return index < pages.count - 1 ? pages[index + 1] : pages.first
   }
}

class FeedCellViewController: UIViewController {
   private let article: Article
   
   init(article: Article) {
       self.article = article
       super.init(nibName: nil, bundle: nil)
   }
   
   required init?(coder: NSCoder) {
       fatalError("init(coder:) has not been implemented")
   }
   
   override func viewDidLoad() {
       super.viewDidLoad()
       setupUI()
   }
   
   private func setupUI() {
       let hostingController = UIHostingController(rootView:
           FeedCell(article: article)
               .edgesIgnoringSafeArea(.all)
       )
       addChild(hostingController)
       view.addSubview(hostingController.view)
       hostingController.view.frame = view.bounds
       hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
       hostingController.didMove(toParent: self)
   }
}
