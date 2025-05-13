import SwiftUI
import FirebaseFirestore

struct AuthorsListView: View {
    @ObservedObject var viewModel: CatalogViewModel
    @State private var searchText: String = ""
    @State private var showingAddAuthor = false
    @State private var isUpdatingAuthors: Bool = false
    @State private var authorsDataExists: Bool = false

    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))

                if !authorsDataExists {
                    Button(action: {
                        isUpdatingAuthors = true
                        viewModel.updateAuthorDetails()
                        checkAuthorsDataCompletion()
                    }) {
                        Text(isUpdatingAuthors ? "Updating Authors..." : "Update Author Details")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isUpdatingAuthors ? Color.gray : Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .disabled(isUpdatingAuthors)
                }

                AuthorListScrollView(viewModel: viewModel, searchText: searchText)
            }
            .navigationTitle("Authors")
            .onAppear {
                viewModel.loadData()
                checkAuthorsDataExists()
            }
        }
    }

    private func checkAuthorsDataExists() {
        db.collection("AuthorsData").getDocuments { snapshot, error in
            if let error = error {
                print("Error checking AuthorsData: \(error.localizedDescription)")
                return
            }
            authorsDataExists = !(snapshot?.documents.isEmpty ?? true)
        }
    }

    private func checkAuthorsDataCompletion() {
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { timer in
            db.collection("AuthorsData").getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking AuthorsData: \(error.localizedDescription)")
                    return
                }
                if let documents = snapshot?.documents, !documents.isEmpty {
                    isUpdatingAuthors = false
                    authorsDataExists = true
                    timer.invalidate()
                }
            }
        }
    }
    
    private struct AuthorListScrollView: View {
        @ObservedObject var viewModel: CatalogViewModel
        let searchText: String
        
        var body: some View {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredSectionedAuthors, id: \.letter) { section in
                        AuthorSectionView(viewModel: viewModel, section: section)
                    }
                }
            }
        }
        
        private var filteredSectionedAuthors: [(letter: String, authors: [Author])] {
            let filteredAuthors = searchText.isEmpty ? viewModel.authors : viewModel.authors.filter {
                $0.name.lowercased().contains(searchText.lowercased())
            }
            let grouped = Dictionary(grouping: filteredAuthors) { author in
                String(author.name.first ?? Character("A")).uppercased()
            }
            return grouped.map { (letter: $0.key, authors: $0.value.sorted { $0.name < $1.name }) }
                .sorted { $0.letter < $1.letter }
        }
    }
    
    private struct AuthorSectionView: View {
        @ObservedObject var viewModel: CatalogViewModel
        let section: (letter: String, authors: [Author])
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(section.letter.uppercased())
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                
                ForEach(section.authors.indices, id: \.self) { index in
                    let author = section.authors[index]
                    let books = viewModel.getBooksByAuthor(author.name)
                    VStack(spacing: 0) {
                        NavigationLink(destination: AuthorDetailView(viewModel: viewModel, author: author)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(author.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
//                                    Text("\(books.count) book\(books.count == 1 ? "" : "s")")
//                                        .font(.subheadline)
//                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .padding(.trailing)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground))
                        }
                        if index < section.authors.count - 1 {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
        }
    }
}

struct AuthorsListView_Previews: PreviewProvider {
    static var previews: some View {
        AuthorsListView(viewModel: CatalogViewModel())
    }
}
