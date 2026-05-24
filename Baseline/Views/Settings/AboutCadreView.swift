import SwiftUI

/// Sub-screen 08: Cadre ecosystem overview.
struct AboutCadreView: View {
    var body: some View {
        ZStack {
            GradientBackground(center: .top)

            ScrollView {
                VStack(spacing: 0) {
                    // Hero: logo + name + desc
                    VStack(spacing: 0) {
                        Text("C")
                            .font(.custom("Exo 2", size: 36, relativeTo: .largeTitle).weight(.heavy))
                            .foregroundStyle(CadreColors.accent)
                            .tracking(-1)
                            .frame(width: 72, height: 72)
                            .background(
                                LinearGradient(
                                    colors: [CadreColors.cardElevated, CadreColors.divider],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 20)
                            )
                            .padding(.bottom, 16)

                        Text("Cadre")
                            .font(.custom("Exo 2", size: 22, relativeTo: .title2).weight(.heavy))
                            .foregroundStyle(CadreColors.textPrimary)
                            .tracking(-0.4)

                        Text("An ecosystem of tools for serious training. Your data, your format, your control.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CadreColors.textTertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                            .padding(.top, 8)
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 16)

                    // App list
                    VStack(spacing: 0) {
                        appRow(
                            letter: "B",
                            name: "Baseline",
                            description: "Weight + body comp tracking",
                            color: CadreColors.accent,
                            badge: "This app",
                            badgeStyle: .current
                        )
                        Rectangle().fill(CadreColors.divider).frame(height: 0.5)
                        appRow(
                            letter: "A",
                            name: "Apex",
                            description: "Strength training logger",
                            color: Color(hex: "B89968"),
                            badge: "Sibling",
                            badgeStyle: .normal
                        )
                        Rectangle().fill(CadreColors.divider).frame(height: 0.5)
                        appRow(
                            letter: "D",
                            name: "Dashboard",
                            description: "Cross-app analytics",
                            color: Color(hex: "8A8278"),
                            badge: "Soon",
                            badgeStyle: .normal
                        )
                    }
                    .background(CadreColors.card, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                }
                .padding(.bottom, CadreSpacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("About Cadre")
                    .font(.custom("Exo 2", size: 17, relativeTo: .headline).weight(.bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.2)
            }
        }
        .toolbarBackground(CadreColors.bgGradientCenter, for: .navigationBar)
    }

    private enum BadgeStyle { case current, normal }

    private func appRow(
        letter: String,
        name: String,
        description: String,
        color: Color,
        badge: String,
        badgeStyle: BadgeStyle
    ) -> some View {
        HStack(spacing: 12) {
            Text(letter)
                .font(.custom("Exo 2", size: 18, relativeTo: .headline).weight(.heavy))
                .foregroundStyle(color)
                .tracking(-0.3)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CadreColors.textPrimary)
                    .tracking(-0.1)
                Text(description)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(CadreColors.textTertiary)
            }

            Spacer()

            Text(badge)
                .font(.system(size: 9, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(badgeStyle == .current ? CadreColors.accent : CadreColors.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    (badgeStyle == .current ? CadreColors.accent.opacity(0.18) : CadreColors.cardElevated),
                    in: RoundedRectangle(cornerRadius: 4)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
