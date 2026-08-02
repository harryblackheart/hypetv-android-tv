import 'package:hypetv/features/home/domain/content_item.dart';

const _signal = ContentItem(
  title: 'Beyond the Signal',
  subtitle: 'Sci-fi · HypeTV Original',
  imageUrl:
      'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?w=900&auto=format&fit=crop',
  badge: 'HYPE',
);
const _horizon = ContentItem(
  title: 'The Last Horizon',
  subtitle: 'S1 E4 · Into the dark',
  imageUrl:
      'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?w=900&auto=format&fit=crop',
  progress: .62,
);
const _neon = ContentItem(
  title: 'Neon City',
  subtitle: 'S2 E1 · After midnight',
  imageUrl:
      'https://images.unsplash.com/photo-1519608487953-e999c86e7455?w=900&auto=format&fit=crop',
  progress: .28,
);
const _wild = ContentItem(
  title: 'Wild North',
  subtitle: 'Episode 3 · The crossing',
  imageUrl:
      'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=900&auto=format&fit=crop',
  progress: .81,
);
const _racing = ContentItem(
  title: 'Grand Prix Live',
  subtitle: 'Live · Sports Arena',
  imageUrl:
      'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?w=900&auto=format&fit=crop',
  badge: 'LIVE',
);
const _news = ContentItem(
  title: 'Hype News',
  subtitle: 'Live · Latest headlines',
  imageUrl:
      'https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=900&auto=format&fit=crop',
  badge: 'LIVE',
);
const _stadium = ContentItem(
  title: 'Match Night',
  subtitle: 'Live · Main event',
  imageUrl:
      'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=900&auto=format&fit=crop',
  badge: 'LIVE',
);
const _concert = ContentItem(
  title: 'Hype Music',
  subtitle: 'Live · Backstage',
  imageUrl:
      'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=900&auto=format&fit=crop',
  badge: 'LIVE',
);
const _redline = ContentItem(
  title: 'Redline',
  subtitle: 'Action · 2026',
  imageUrl:
      'https://images.unsplash.com/photo-1504215680853-026ed2a45def?w=900&auto=format&fit=crop',
  badge: 'TOP 10',
);
const _afterHours = ContentItem(
  title: 'After Hours',
  subtitle: 'Thriller · 2026',
  imageUrl:
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=900&auto=format&fit=crop',
  badge: 'NEW',
);
const _summit = ContentItem(
  title: 'The Summit',
  subtitle: 'Adventure · 2025',
  imageUrl:
      'https://images.unsplash.com/photo-1464278533981-50106e6176b1?w=900&auto=format&fit=crop',
);
const _origins = ContentItem(
  title: 'Origins',
  subtitle: 'Documentary · 2026',
  imageUrl:
      'https://images.unsplash.com/photo-1500534623283-312aade485b7?w=900&auto=format&fit=crop',
);
const _underground = ContentItem(
  title: 'The Underground',
  subtitle: 'Drama · 6 episodes',
  imageUrl:
      'https://images.unsplash.com/photo-1518005020951-eccb494ad742?w=900&auto=format&fit=crop',
  badge: 'HYPE',
);
const _openWater = ContentItem(
  title: 'Open Water',
  subtitle: 'Adventure · 4 episodes',
  imageUrl:
      'https://images.unsplash.com/photo-1551244072-5d12893278ab?w=900&auto=format&fit=crop',
  badge: 'HYPE',
);
const _nightShift = ContentItem(
  title: 'Night Shift',
  subtitle: 'Crime · 10 episodes',
  imageUrl:
      'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=900&auto=format&fit=crop',
  badge: 'HYPE',
);

const demoShelves = [
  ContentShelf(
    title: 'Continue Watching',
    items: [_horizon, _neon, _wild, _racing],
  ),
  ContentShelf(title: 'Live TV', items: [_news, _racing, _stadium, _concert]),
  ContentShelf(
    title: 'Trending Movies',
    items: [_redline, _afterHours, _summit, _origins],
  ),
  ContentShelf(
    title: 'Latest Series',
    items: [_neon, _underground, _nightShift, _wild],
  ),
  ContentShelf(
    title: 'Recently Added',
    items: [_afterHours, _signal, _openWater, _redline],
  ),
  ContentShelf(
    title: 'HypeTV Originals',
    items: [_signal, _underground, _openWater, _nightShift],
  ),
  ContentShelf(
    title: 'Sports Tonight',
    items: [_stadium, _racing, _wild, _summit],
  ),
  ContentShelf(title: 'News', items: [_news, _origins, _concert, _afterHours]),
];
