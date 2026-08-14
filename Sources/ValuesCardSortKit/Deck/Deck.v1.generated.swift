// SPDX-License-Identifier: GPL-3.0-or-later
//
// GENERATED FILE — DO NOT EDIT.
//
// Produced by scripts/generate_deck.py from data/deck.v1.json.
// Regenerate with: ./scripts/generate-deck.sh
//
// The deck is compiled in rather than bundled as a JSON resource so that
// the shipped app has no editable copy of the instrument text, and so a
// hand edit here fails CI's regeneration check as well as the payload
// hash. See scripts/generate_deck.py for the full rationale (SPEC §4).
//
// The pinned payload hash deliberately does NOT live in this file. It is
// hand-maintained in DeckLoader.swift, so changing a card here cannot be
// covered up by editing the constant on the next line.
//
// The instrument itself is public domain:
//   Personal Values Card Sort
//   W. R. Miller, J. C'de Baca, D. B. Matthews, P. L. Wilbourne
//   University of New Mexico, 2001

extension Deck {
    /// The deck as published, compiled into the binary.
    public static let v1 = Deck(
        deckVersion: "1.0.0",
        instrument: Instrument(
            title: "Personal Values Card Sort",
            authors: "W. R. Miller, J. C'de Baca, D. B. Matthews, P. L. Wilbourne",
            institution: "University of New Mexico",
            year: 2001,
            copyright: "Public domain",
            sources: [
                "https://motivationalinterviewing.org/personal-values-card-sort",
                "https://motivationalinterviewing.org/sites/default/files/valuescardsort_0.pdf",
                "https://casaa.unm.edu/assets/inst/personal-values-card-sort.pdf",
            ],
            verification: "PENDING card-by-card check against fixtures/ PDFs (chore C1)"
        ),
        cardCount: 83,
        cards: [
            ValueCard(id: 1, name: "ACCEPTANCE", descriptor: "to be accepted as I am"),
            ValueCard(id: 2, name: "ACCURACY", descriptor: "to be accurate in my opinions and beliefs"),
            ValueCard(id: 3, name: "ACHIEVEMENT", descriptor: "to have important accomplishments"),
            ValueCard(id: 4, name: "ADVENTURE", descriptor: "to have new and exciting experiences"),
            ValueCard(id: 5, name: "ATTRACTIVENESS", descriptor: "to be physically attractive"),
            ValueCard(id: 6, name: "AUTHORITY", descriptor: "to be in charge of and responsible for others"),
            ValueCard(id: 7, name: "AUTONOMY", descriptor: "to be self-determined and independent"),
            ValueCard(id: 8, name: "BEAUTY", descriptor: "to appreciate beauty around me"),
            ValueCard(id: 9, name: "CARING", descriptor: "to take care of others"),
            ValueCard(id: 10, name: "CHALLENGE", descriptor: "to take on difficult tasks and problems"),
            ValueCard(id: 11, name: "CHANGE", descriptor: "to have a life full of change and variety"),
            ValueCard(id: 12, name: "COMFORT", descriptor: "to have a pleasant and comfortable life"),
            ValueCard(id: 13, name: "COMMITMENT", descriptor: "to make enduring, meaningful commitments"),
            ValueCard(id: 14, name: "COMPASSION", descriptor: "to feel and act on concern for others"),
            ValueCard(id: 15, name: "CONTRIBUTION", descriptor: "to make a lasting contribution in the world"),
            ValueCard(id: 16, name: "COOPERATION", descriptor: "to work collaboratively with others"),
            ValueCard(id: 17, name: "COURTESY", descriptor: "to be considerate and polite toward others"),
            ValueCard(id: 18, name: "CREATIVITY", descriptor: "to have new and original ideas"),
            ValueCard(id: 19, name: "DEPENDABILITY", descriptor: "to be reliable and trustworthy"),
            ValueCard(id: 20, name: "DUTY", descriptor: "to carry out my duties and obligations"),
            ValueCard(id: 21, name: "ECOLOGY", descriptor: "to live in harmony with the environment"),
            ValueCard(id: 22, name: "EXCITEMENT", descriptor: "to have a life full of thrills and stimulation"),
            ValueCard(id: 23, name: "FAITHFULNESS", descriptor: "to be loyal and true in relationships"),
            ValueCard(id: 24, name: "FAME", descriptor: "to be known and recognized"),
            ValueCard(id: 25, name: "FAMILY", descriptor: "to have a happy, loving family"),
            ValueCard(id: 26, name: "FITNESS", descriptor: "to be physically fit and strong"),
            ValueCard(id: 27, name: "FLEXIBILITY", descriptor: "to adjust to new circumstances easily"),
            ValueCard(id: 28, name: "FORGIVENESS", descriptor: "to be forgiving of others"),
            ValueCard(id: 29, name: "FRIENDSHIP", descriptor: "to have close, supportive friends"),
            ValueCard(id: 30, name: "FUN", descriptor: "to play and have fun"),
            ValueCard(id: 31, name: "GENEROSITY", descriptor: "to give what I have to others"),
            ValueCard(id: 32, name: "GENUINENESS", descriptor: "to act in a manner that is true to who I am"),
            ValueCard(id: 33, name: "GOD'S WILL", descriptor: "to seek and obey the will of God"),
            ValueCard(id: 34, name: "GROWTH", descriptor: "to keep changing and growing"),
            ValueCard(id: 35, name: "HEALTH", descriptor: "to be physically well and healthy"),
            ValueCard(id: 36, name: "HELPFULNESS", descriptor: "to be helpful to others"),
            ValueCard(id: 37, name: "HONESTY", descriptor: "to be honest and truthful"),
            ValueCard(id: 38, name: "HOPE", descriptor: "to maintain a positive and optimistic outlook"),
            ValueCard(id: 39, name: "HUMILITY", descriptor: "to be modest and unassuming"),
            ValueCard(id: 40, name: "HUMOR", descriptor: "to see the humorous side of myself and the world"),
            ValueCard(id: 41, name: "INDEPENDENCE", descriptor: "to be free from dependence on others"),
            ValueCard(id: 42, name: "INDUSTRY", descriptor: "to work hard and well at my life tasks"),
            ValueCard(id: 43, name: "INNER PEACE", descriptor: "to experience personal peace"),
            ValueCard(id: 44, name: "INTIMACY", descriptor: "to share my innermost experiences with others"),
            ValueCard(id: 45, name: "JUSTICE", descriptor: "to promote fair and equal treatment for all"),
            ValueCard(id: 46, name: "KNOWLEDGE", descriptor: "to learn and contribute valuable knowledge"),
            ValueCard(id: 47, name: "LEISURE", descriptor: "to take time to relax and enjoy"),
            ValueCard(id: 48, name: "LOVED", descriptor: "to be loved by those close to me"),
            ValueCard(id: 49, name: "LOVING", descriptor: "to give love to others"),
            ValueCard(id: 50, name: "MASTERY", descriptor: "to be competent in my everyday activities"),
            ValueCard(id: 51, name: "MINDFULNESS", descriptor: "to live conscious and mindful of the present moment"),
            ValueCard(id: 52, name: "MODERATION", descriptor: "to avoid excesses and find a middle ground"),
            ValueCard(id: 53, name: "MONOGAMY", descriptor: "to have one close, loving relationship"),
            ValueCard(id: 54, name: "NON-CONFORMITY", descriptor: "to question and challenge authority and norms"),
            ValueCard(id: 55, name: "NURTURANCE", descriptor: "to take care of and nurture others"),
            ValueCard(id: 56, name: "OPENNESS", descriptor: "to be open to new experiences, ideas, and options"),
            ValueCard(id: 57, name: "ORDER", descriptor: "to have a life that is well-ordered and organized"),
            ValueCard(id: 58, name: "PASSION", descriptor: "to have deep feelings about ideas, activities, or people"),
            ValueCard(id: 59, name: "PLEASURE", descriptor: "to feel good"),
            ValueCard(id: 60, name: "POPULARITY", descriptor: "to be well-liked by many people"),
            ValueCard(id: 61, name: "POWER", descriptor: "to have control over others"),
            ValueCard(id: 62, name: "PURPOSE", descriptor: "to have meaning and direction in my life"),
            ValueCard(id: 63, name: "RATIONALITY", descriptor: "to be guided by reason and logic"),
            ValueCard(id: 64, name: "REALISM", descriptor: "to see and act realistically and practically"),
            ValueCard(id: 65, name: "RESPONSIBILITY", descriptor: "to make and carry out responsible decisions"),
            ValueCard(id: 66, name: "RISK", descriptor: "to take risks and chances"),
            ValueCard(id: 67, name: "ROMANCE", descriptor: "to have intense, exciting love in my life"),
            ValueCard(id: 68, name: "SAFETY", descriptor: "to be safe and secure"),
            ValueCard(id: 69, name: "SELF-ACCEPTANCE", descriptor: "to accept myself as I am"),
            ValueCard(id: 70, name: "SELF-CONTROL", descriptor: "to be disciplined in my own actions"),
            ValueCard(id: 71, name: "SELF-ESTEEM", descriptor: "to feel good about myself"),
            ValueCard(id: 72, name: "SELF-KNOWLEDGE", descriptor: "to have a deep and honest understanding of myself"),
            ValueCard(id: 73, name: "SERVICE", descriptor: "to be of service to others"),
            ValueCard(id: 74, name: "SEXUALITY", descriptor: "to have an active and satisfying sex life"),
            ValueCard(id: 75, name: "SIMPLICITY", descriptor: "to live life simply, with minimal needs"),
            ValueCard(id: 76, name: "SOLITUDE", descriptor: "to have time and space where I can be apart from others"),
            ValueCard(id: 77, name: "SPIRITUALITY", descriptor: "to grow and mature spiritually"),
            ValueCard(id: 78, name: "STABILITY", descriptor: "to have a life that stays fairly consistent"),
            ValueCard(id: 79, name: "TOLERANCE", descriptor: "to accept and respect those who differ from me"),
            ValueCard(id: 80, name: "TRADITION", descriptor: "to follow respected patterns of the past"),
            ValueCard(id: 81, name: "VIRTUE", descriptor: "to live a morally pure and excellent life"),
            ValueCard(id: 82, name: "WEALTH", descriptor: "to have plenty of money"),
            ValueCard(id: 83, name: "WORLD PEACE", descriptor: "to work to promote peace in the world"),
        ]
    )
}
