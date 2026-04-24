import SwiftUI
import SwiftData

enum Tab: String, CaseIterable {
    case sign = "Sign"
    case timetable = "Timetable"
}

struct MainTabView: View {
    @State private var selectedTab: Tab = .sign
    @Environment(AuthManager.self) private var auth

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
                .padding(.horizontal)
                .padding(.top, 8)

            TabView(selection: $selectedTab) {
                SignTabView()
                    .tag(Tab.sign)

                TimetableView()
                    .tag(Tab.timetable)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? Color.white : Color.clear)
                        )
                        .foregroundStyle(selectedTab == tab ? .black : .white)
                }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.15))
        )
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Course.self, Signature.self], inMemory: true)
        .environment(AuthManager())
}
