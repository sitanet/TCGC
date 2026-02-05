import '../../domain/entities/sermon.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/teens_content.dart';

class MockData {
  static List<Sermon> get sermons => [
        Sermon(
          id: '1',
          title: 'The Morning Dew',
          description: 'It is a time for to come together to worship, hear God\'s word, and fellowship.',
          imageUrl: 'assets/images/morning_dew.png',
          audioUrl: 'https://example.com/audio1.mp3',
          category: 'The Morning Dew',
          date: DateTime.now(),
          duration: const Duration(minutes: 45),
        ),
        Sermon(
          id: '2',
          title: 'Feast of Glory Service',
          description: 'It is a time for to come together to worship, hear God\'s word, and fellowship.',
          imageUrl: 'assets/images/feast_of_glory.png',
          audioUrl: 'https://example.com/audio2.mp3',
          category: 'Feast of Glory Service',
          date: DateTime.now(),
          duration: const Duration(hours: 1, minutes: 30),
        ),
        Sermon(
          id: '3',
          title: 'Word and Prayer',
          description: 'It is a time for to come together to worship, hear God\'s word, and fellowship.',
          imageUrl: 'assets/images/word_prayer.png',
          audioUrl: 'https://example.com/audio3.mp3',
          category: 'Word and Prayer',
          date: DateTime.now(),
          duration: const Duration(minutes: 60),
        ),
        Sermon(
          id: '4',
          title: 'The School of Christ',
          description: 'It is a time for to come together to worship, hear God\'s word, and fellowship.',
          imageUrl: 'assets/images/school_of_christ.png',
          audioUrl: 'https://example.com/audio4.mp3',
          category: 'The School of Christ',
          date: DateTime.now(),
          duration: const Duration(minutes: 90),
        ),
        Sermon(
          id: '5',
          title: "Baba's Blessing",
          description: 'It is a time for to come together to worship, hear God\'s word, and fellowship.',
          imageUrl: 'assets/images/babas_blessing.png',
          audioUrl: 'https://example.com/audio5.mp3',
          category: "Baba's Blessing",
          date: DateTime.now(),
          duration: const Duration(minutes: 30),
        ),
      ];

  static List<Event> get events => [
        const Event(
          id: '1',
          title: 'Sunday Service',
          description: 'Join us for Sunday worship',
          imageUrl: 'assets/images/sunday_service.png',
          schedule: 'Every Sunday 8:00am',
          iconColor: 'gold',
          isLive: true,
        ),
        const Event(
          id: '2',
          title: 'Word & Prayer',
          description: 'Mid-week prayer meeting',
          imageUrl: 'assets/images/word_prayer.png',
          schedule: 'Every Tuesday 5:00pm',
          iconColor: 'maroon',
        ),
        const Event(
          id: '3',
          title: 'The School of Christ',
          description: 'Bible study and teaching',
          imageUrl: 'assets/images/school_of_christ.png',
          schedule: 'Every Thursday 6:00pm',
          iconColor: 'blue',
        ),
      ];

  static List<Event> get teensEvents => [
        const Event(
          id: '1',
          title: 'Daily Devotional',
          description: 'Start your day with God',
          imageUrl: 'assets/images/daily_devotional.png',
          schedule: 'Everyday - 8:00am',
          iconColor: 'orange',
        ),
        const Event(
          id: '2',
          title: 'Teens Retreat',
          description: 'Monthly teens gathering',
          imageUrl: 'assets/images/teens_retreat.png',
          schedule: 'Every Month',
          iconColor: 'maroon',
        ),
        const Event(
          id: '3',
          title: 'The Forge Teens Camp',
          description: 'Weekly teens meeting',
          imageUrl: 'assets/images/forge_camp.png',
          schedule: 'Every Thursday 5:30pm',
          iconColor: 'teal',
        ),
      ];

  static List<Transaction> get transactions => [
        Transaction(
          id: '1',
          title: 'Money In',
          amount: 50000,
          currency: 'NGN',
          type: TransactionType.moneyIn,
          date: DateTime.now(),
        ),
        Transaction(
          id: '2',
          title: 'Money Out',
          amount: 20000,
          currency: 'NGN',
          type: TransactionType.moneyOut,
          date: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];

  static List<String> get giveOptions => [
        'Offering',
        'Tithe',
        'Project: Baba\'s Land',
        'Branches',
        'Special Offering',
        'Giving to Ministers',
        'IMGC',
      ];

  static List<TeensContent> get dailyDevotionals => [
        TeensContent(
          id: '1',
          title: 'Walking in Faith',
          description: 'Learn how to trust God in every situation and walk by faith, not by sight. This devotional explores practical ways to strengthen your faith daily.',
          thumbnailUrl: 'assets/images/teens_banner.png',
          category: 'Daily Devotional',
          date: DateTime.now(),
          duration: const Duration(minutes: 10),
        ),
        TeensContent(
          id: '2',
          title: 'The Power of Prayer',
          description: 'Discover the transformative power of prayer in your life. Learn how to communicate with God effectively and see results.',
          thumbnailUrl: 'assets/images/teens_banner.png',
          category: 'Daily Devotional',
          date: DateTime.now().subtract(const Duration(days: 1)),
          duration: const Duration(minutes: 12),
        ),
        TeensContent(
          id: '3',
          title: 'Living with Purpose',
          description: 'God has a unique purpose for your life. This devotional helps you discover and walk in your God-given destiny.',
          thumbnailUrl: 'assets/images/teens_banner.png',
          category: 'Daily Devotional',
          date: DateTime.now().subtract(const Duration(days: 2)),
          duration: const Duration(minutes: 8),
        ),
        TeensContent(
          id: '4',
          title: 'Overcoming Temptation',
          description: 'Practical strategies for overcoming temptation and living a life that honors God in every area.',
          thumbnailUrl: 'assets/images/teens_banner.png',
          category: 'Daily Devotional',
          date: DateTime.now().subtract(const Duration(days: 3)),
          duration: const Duration(minutes: 15),
        ),
        TeensContent(
          id: '5',
          title: 'Finding Peace in Chaos',
          description: 'Learn how to maintain inner peace even when life gets chaotic. God\'s peace surpasses all understanding.',
          thumbnailUrl: 'assets/images/teens_banner.png',
          category: 'Daily Devotional',
          date: DateTime.now().subtract(const Duration(days: 4)),
          duration: const Duration(minutes: 10),
        ),
      ];

  static List<TeensContent> get teensRetreats => [
        TeensContent(
          id: '1',
          title: 'Teens Retreat 2024 - Session 1',
          description: 'Opening session of the annual teens retreat focusing on identity in Christ and discovering your purpose.',
          thumbnailUrl: 'assets/images/teens_banner.png',
          category: 'Teens Retreat',
          date: DateTime(2024, 12, 15),
          duration: const Duration(hours: 1, minutes: 30),
        ),
        TeensContent(
          id: '2',
          title: 'Teens Retreat 2024 - Session 2',
          description: 'Deep dive into building strong relationships and navigating friendships as a young Christian.',
          thumbnailUrl: 'assets/images/teens_banner.png',
          category: 'Teens Retreat',
          date: DateTime(2024, 12, 15),
          duration: const Duration(hours: 1, minutes: 45),
        ),
        TeensContent(
          id: '3',
          title: 'Teens Retreat 2024 - Session 3',
          description: 'Worship and prayer session. Learning to connect with God in a deeper way.',
          thumbnailUrl: 'assets/images/teens_banner.png',
          category: 'Teens Retreat',
          date: DateTime(2024, 12, 16),
          duration: const Duration(hours: 2),
        ),
        TeensContent(
          id: '4',
          title: 'Teens Retreat 2023 Highlights',
          description: 'Recap of the powerful moments from last year\'s teens retreat.',
          thumbnailUrl: 'assets/images/teens_banner.png',
          category: 'Teens Retreat',
          date: DateTime(2023, 12, 20),
          duration: const Duration(minutes: 45),
        ),
      ];

  static List<TeensContent> get forgeTeensCamp => [
        TeensContent(
          id: '1',
          title: 'The Forge - Week 1: Foundation',
          description: 'Building a strong spiritual foundation. Understanding the basics of faith and what it means to follow Christ.',
          thumbnailUrl: 'assets/images/teens_banner.png',
          category: 'The Forge Teens Camp',
          date: DateTime.now().subtract(const Duration(days: 7)),
          duration: const Duration(hours: 1),
        ),
        TeensContent(
          id: '2',
          title: 'The Forge - Week 2: Character',
          description: 'Developing godly character. Learning integrity, honesty, and walking in love.',
          thumbnailUrl: 'assets/images/teens_banner.png',
          category: 'The Forge Teens Camp',
          date: DateTime.now().subtract(const Duration(days: 14)),
          duration: const Duration(hours: 1, minutes: 15),
        ),
        TeensContent(
          id: '3',
          title: 'The Forge - Week 3: Purpose',
          description: 'Discovering your God-given purpose and how to pursue it with passion.',
          thumbnailUrl: 'assets/images/teens_banner.png',
          category: 'The Forge Teens Camp',
          date: DateTime.now().subtract(const Duration(days: 21)),
          duration: const Duration(hours: 1, minutes: 10),
        ),
        TeensContent(
          id: '4',
          title: 'The Forge - Week 4: Leadership',
          description: 'Becoming a leader in your generation. Servant leadership and influence.',
          thumbnailUrl: 'assets/images/teens_banner.png',
          category: 'The Forge Teens Camp',
          date: DateTime.now().subtract(const Duration(days: 28)),
          duration: const Duration(hours: 1, minutes: 20),
        ),
        TeensContent(
          id: '5',
          title: 'The Forge - Week 5: Mission',
          description: 'Understanding the Great Commission and your role in spreading the gospel.',
          thumbnailUrl: 'assets/images/teens_banner.png',
          category: 'The Forge Teens Camp',
          date: DateTime.now().subtract(const Duration(days: 35)),
          duration: const Duration(hours: 1, minutes: 30),
        ),
      ];
}
