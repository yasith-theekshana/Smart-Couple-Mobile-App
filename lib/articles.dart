import 'package:flutter/material.dart';

import 'ui.dart';

const articleImages = [
  'article.jpg',
  'love.jpg',
  'forgiveness.jpg',
  'vision.jpg',
];
const readTimes = ['5', '6', '4', '8'];
const titles = [
  ['L’art de l’écoute active', 'Active Listening as a Couple'],
  ['Les 5 langages de l’amour', 'The five love languages'],
  ['Le pardon au quotidien', 'Everyday forgiveness'],
  ['Bâtir une Vision Commune', 'Building a shared vision'],
];
const descriptions = [
  [
    'Transformez vos désaccords en moments de connexion grâce à des techniques d’écoute bienveillante.',
    'Discover how practicing active listening can strengthen your emotional connections and avoid unnecessary misunderstandings.',
  ],
  [
    'Comprendre comment votre partenaire exprime et reçoit de l’affection est la clé d’une harmonie durable.',
    'Understanding how your partner expresses and receives affection helps build lasting harmony.',
  ],
  [
    'Comment lâcher prise sur les petites frustrations pour éviter qu’elles ne deviennent des murs.',
    'Let go of small frustrations before they become walls between you.',
  ],
  [
    'Pourquoi et comment créer un « Vision Board » pour vos projets de vie à deux.',
    'Create a vision board for the life you want to build together.',
  ],
];
const bodies = [
  [
    'L’écoute active n’est pas simplement le fait de se taire pendant que l’autre parle. C’est un engagement total envers la compréhension.\n\nLe premier obstacle à une bonne communication est la distraction. Posez votre téléphone, éteignez la télévision et tournez votre corps vers votre partenaire. Le contact visuel montre que ce qu’ils disent a de la valeur.',
    'Active listening means committing to understanding your partner.\n\nPut your phone away, turn off the television, and give your partner your full attention. Eye contact shows that what they say matters.',
  ],
  [
    'Tout le monde n’exprime pas l’amour de la même manière.\n\nGary Chapman a identifié 5 piliers : les paroles valorisantes, les moments de qualité, les cadeaux, les services rendus et le toucher physique.',
    'People express love in different ways.\n\nGary Chapman described five love languages: words of affirmation, quality time, gifts, acts of service, and physical touch.',
  ],
  [
    'Pardonner ne signifie pas oublier ou valider une erreur, mais décider que la relation est plus importante que l’offense. Cela demande une pratique quotidienne des petits pardons.',
    'Forgiveness does not mean forgetting or excusing a mistake. It means choosing to move forward together, with daily practice and honest conversation.',
  ],
  [
    'Un couple qui ne rêve plus ensemble finit par s’ennuyer. Prenez une soirée pour découper des images, lister vos objectifs financiers et vos envies de voyages.',
    'Set aside an evening to collect images, write down financial goals, and talk about the places you want to visit together. Make room for both partners’ dreams.',
  ],
];

class ArticleCard extends StatelessWidget {
  final int index;
  final bool french;
  const ArticleCard({super.key, required this.index, required this.french});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ArticleReader(index: index, french: french),
      ),
    ),
    borderRadius: BorderRadius.circular(24),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: gold, width: 2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.asset(
                'assets/images/${articleImages[index]}',
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned(
                bottom: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  color: gold,
                  child: Text(
                    index == 0
                        ? 'COMMUNICATION'
                        : (french ? 'VIE À DEUX' : 'LIFE TOGETHER'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titles[index][french ? 0 : 1], style: serif(21)),
                const SizedBox(height: 10),
                Text(
                  descriptions[index][french ? 0 : 1],
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '${french ? 'LIRE ARTICLE' : 'READ ARTICLE'}  →',
                  style: eyebrow(),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void openArticles(BuildContext context, bool french) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (_) => Scaffold(
      appBar: AppBar(title: Text('Articles', style: serif(25))),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: titles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 20),
        itemBuilder: (_, i) => ArticleCard(index: i, french: french),
      ),
    ),
  ),
);

class ArticleReader extends StatelessWidget {
  final int index;
  final bool french;
  const ArticleReader({super.key, required this.index, required this.french});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Smart Union', style: serif(23))),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            'assets/images/${articleImages[index]}',
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 24),
        Text('SMART UNION · ${readTimes[index]} MIN', style: eyebrow(gold)),
        const SizedBox(height: 12),
        Text(titles[index][french ? 0 : 1], style: serif(30)),
        const SizedBox(height: 20),
        Text(
          descriptions[index][french ? 0 : 1],
          style: const TextStyle(fontSize: 17, height: 1.8),
        ),
        const SizedBox(height: 20),
        Text(
          bodies[index][french ? 0 : 1],
          style: const TextStyle(fontSize: 15, height: 1.9),
        ),
      ],
    ),
  );
}
