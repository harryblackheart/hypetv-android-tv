import 'package:hypetv/features/home/data/catalogue_service.dart';

enum LiveBouquetBucket {
  entertainment,
  movies,
  sports,
  news,
  documentaries,
  kids,
  music,
  regional,
  international,
}

String _norm(String value) => value
    .toLowerCase()
    .replaceAll('&', 'and')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

bool isAdultBouquetName(String name) {
  final n = _norm(name);
  return n == 'xxx adult' ||
      n.startsWith('xxx adult ') ||
      n.contains(' adult xxx');
}

class BouquetAutoMapper {
  static Set<String> idsFor(
    LiveBouquetBucket bucket,
    List<CatalogueCategory> categories,
  ) {
    return categories
        .where((category) => matches(bucket, category.name))
        .map((category) => category.id)
        .whereType<String>()
        .toSet();
  }

  static bool matches(LiveBouquetBucket bucket, String name) {
    final n = _norm(name);
    if (isAdultBouquetName(name)) return false;

    bool has(String value) => n.contains(value);
    bool exact(String value) => n == _norm(value);

    switch (bucket) {
      case LiveBouquetBucket.movies:
        // Live movie bouquets only. Premium VOD belongs to the VOD catalogue.
        return exact('UK | Movies') ||
            exact('USA | Movies') ||
            exact('Canada | Movies') ||
            (has(' movies') &&
                !has('premium vod') &&
                !has('vod') &&
                !has('24 7 tv shows'));

      case LiveBouquetBucket.entertainment:
        return exact('UK | Entertainment') ||
            exact('USA | Entertainment') ||
            exact('Canada | Entertainment') ||
            exact('24/7 TV Shows') ||
            has(' entertainment');

      case LiveBouquetBucket.sports:
        const exactSports = <String>[
          'Sky Sports',
          'BT Sports',
          'UK | Sports and Betting',
          'USA | Sports',
          'Canada | Sports',
          'EPL Hub',
          'EFL HUB',
          'SPFL Hub',
          'BeIN/Supersport',
          'Cricket HUB',
          'F1/flo/dirtvision',
          'NFL HUB',
          'WNBA HUB',
          'NBA HUB',
          'NHL HUB',
          'MLB HUB',
          'ESPN Plus',
          'Outdoors HUB',
          'UFC HUB',
          'Golf HUB',
          'Rugby HUB',
          'Tennis HUB',
          'Horse Racing HUB',
          'PPV | Live Events',
        ];
        return exactSports.any(exact) ||
            has(' sport') ||
            has('sports ') ||
            has(' hub') && (
              has('epl') || has('efl') || has('spfl') ||
              has('ufc') || has('nfl') || has('nba') ||
              has('wnba') || has('nhl') || has('mlb') ||
              has('golf') || has('rugby') || has('tennis') ||
              has('horse racing') || has('cricket')
            );

      case LiveBouquetBucket.news:
        return exact('UK | News') ||
            exact('USA | News') ||
            exact('Canada | News') ||
            has(' news');

      case LiveBouquetBucket.documentaries:
        return exact('UK | Documentaries') ||
            has('documentar') ||
            has('discovery');

      case LiveBouquetBucket.kids:
        return exact('UK | Kids') ||
            exact('USA | Kids') ||
            exact('Canada | Kids') ||
            has(' kids');

      case LiveBouquetBucket.music:
        return exact('UK/USA Music') ||
            exact('Canada Music') ||
            has(' music');

      case LiveBouquetBucket.regional:
        return exact('UK | Regional') ||
            has(' locals') ||
            exact('Canada | Locals') ||
            exact('USA | ABC Locals') ||
            exact('USA | CBS Locals') ||
            exact('USA | FOX Locals') ||
            exact('USA | NBC Locals') ||
            exact('USA | Univision Locals') ||
            exact('USA | Telemundo Locals') ||
            exact('USA CW Locals') ||
            exact('USA MY Locals') ||
            exact('USA PBS Locals');

      case LiveBouquetBucket.international:
        const names = <String>[
          'Irish', 'Africa', 'Arabic', 'Australia', 'Brazil', 'Caribbean',
          'EX-YU', 'France', 'Germany', 'Hungary', 'India', 'Indonesia',
          'Israel', 'Italian', 'Latino', 'Malaysia',
          'MX/ARG/BOL/PY/CI/COL/PE/HN/ECU', 'Netherlands', 'Portuguese',
          'Pakistan/iran', 'Poland/Czech', 'Romania', 'Scandinavian',
          'South Africa', 'Spain/Belgium/Malta', 'Thailand/Philippines',
          'Turkey/Greece', 'Albania', 'Bulgaria', 'Croatia', 'Russia',
          'USA Unimas', 'Canada | French', 'UK | Asian', 'USA | Asian',
        ];
        return names.any(exact);
    }
  }
}
