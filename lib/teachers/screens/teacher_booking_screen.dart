import 'dart:math';
import 'package:flutter/material.dart';

// ─── Design tokens (matches dashboard _C palette) ─────────────────────────────
class _C {
  static const violet = Color(0xFF6C5CE7);
  static const violetDeep = Color(0xFF5847D1);
  static const violetPale = Color(0xFFEFEAFE);
  static const amberPale = Color(0xFFFFF0DC);
  static const coral = Color(0xFFFF8FA3);
  static const coralPale = Color(0xFFFFE9ED);
  static const teal = Color(0xFF3FC6BD);
  static const tealPale = Color(0xFFE2F8F6);
  static const cream = Color(0xFFFFF8F0);
  static const ink = Color(0xFF2D2A4A);
  static const inkSoft = Color(0xFF7A769B);
  static const line = Color(0xFFECE7F7);
  static const paper = Color(0xFFFFFFFF);
  static const bg = Color(0xFFF7F3FE);
  static const green = Color(0xFF00C48C);
  static const greenPale = Color(0xFFDCF7EE);
  static const amber = Color(0xFFFFB86B);
}

// ─── Teacher data model ────────────────────────────────────────────────────────
class TeacherModel {
  final String id;
  final String emoji;
  final String name;
  final String nameCn;
  final String subjects;
  final String subjectsCn;
  final String bio;
  final String bioCn;
  final double rating;
  final int reviewCount;
  final int sessionsDone;
  final int creditsPerSession;
  final List<String> tags;
  final List<String> availability;
  final String level;
  final Color gradientA;
  final Color gradientB;
  final bool isOnline;
  final List<TestimonialModel> testimonials;
  final List<String> certifications;
  final String responseTime;
  final int yearsExp;

  const TeacherModel({
    required this.id,
    required this.emoji,
    required this.name,
    required this.nameCn,
    required this.subjects,
    required this.subjectsCn,
    required this.bio,
    required this.bioCn,
    required this.rating,
    required this.reviewCount,
    required this.sessionsDone,
    required this.creditsPerSession,
    required this.tags,
    required this.availability,
    required this.level,
    required this.gradientA,
    required this.gradientB,
    required this.isOnline,
    required this.testimonials,
    required this.certifications,
    required this.responseTime,
    required this.yearsExp,
  });
}

class TestimonialModel {
  final String studentName;
  final String studentEmoji;
  final int stars;
  final String text;
  final String textCn;
  final String date;
  final String subject;

  const TestimonialModel({
    required this.studentName,
    required this.studentEmoji,
    required this.stars,
    required this.text,
    required this.textCn,
    required this.date,
    required this.subject,
  });
}

// ─── Mock data ────────────────────────────────────────────────────────────────
final _kTeachers = [
  const TeacherModel(
    id: 't1',
    emoji: '👩‍🏫',
    name: 'Ms. Sarah Chen',
    nameCn: '陈老师',
    subjects: 'English · IELTS · Speaking',
    subjectsCn: '英语 · 雅思 · 口语',
    bio:
        'Native English speaker with 8 years teaching ESL and IELTS. I focus on real-world conversation and exam strategy. My students average a 1-band improvement in just 6 weeks.',
    bioCn: '英语母语者，8年ESL和雅思教学经验，专注于真实对话和考试策略。我的学生平均6周内提升一个分段。',
    rating: 4.9,
    reviewCount: 128,
    sessionsDone: 342,
    creditsPerSession: 8,
    tags: ['IELTS', 'Speaking', 'Pronunciation', 'Business'],
    availability: ['Mon', 'Tue', 'Thu', 'Fri'],
    level: 'All Levels',
    gradientA: Color(0xFFFFD9A0),
    gradientB: _C.coral,
    isOnline: true,
    certifications: ['CELTA', 'IELTS Examiner', 'Delta L3'],
    responseTime: '< 1 hour',
    yearsExp: 8,
    testimonials: [
      TestimonialModel(
        studentName: 'Daniel R.',
        studentEmoji: '🙂',
        stars: 5,
        text:
            'Ms. Chen explained things so clearly — my speaking confidence improved in just three sessions. She gives very detailed feedback on pronunciation.',
        textCn: '陈老师讲解得非常清晰，仅仅三节课我的口语信心就提升了。她对发音给出了非常详细的反馈。',
        date: 'Jun 2025',
        subject: 'English Speaking',
      ),
      TestimonialModel(
        studentName: 'Priya M.',
        studentEmoji: '😊',
        stars: 5,
        text:
            'I went from 6.5 to 7.5 in IELTS after 8 sessions. The structured feedback after every class was a game-changer.',
        textCn: '经过8节课后，我的雅思从6.5提升到了7.5。每节课后的结构化反馈让我受益匪浅。',
        date: 'May 2025',
        subject: 'IELTS Prep',
      ),
      TestimonialModel(
        studentName: 'Tom K.',
        studentEmoji: '😄',
        stars: 5,
        text:
            'Best English teacher I\'ve ever had. Patient, funny, and incredibly effective. Highly recommend!',
        textCn: '我遇到过最好的英语老师。耐心、风趣，而且效果极好。强烈推荐！',
        date: 'Apr 2025',
        subject: 'Business English',
      ),
    ],
  ),
  const TeacherModel(
    id: 't2',
    emoji: '👨‍🏫',
    name: 'Mr. James Wang',
    nameCn: '王老师',
    subjects: 'Mandarin · HSK · Grammar',
    subjectsCn: '普通话 · 汉语水平考试 · 语法',
    bio:
        'Beijing-native Mandarin teacher with HSK 6 certification background. Specialist in rapid vocabulary acquisition and tonal accuracy for non-native speakers.',
    bioCn: '北京本地普通话教师，专门帮助非母语学习者快速掌握词汇和声调准确性。',
    rating: 4.8,
    reviewCount: 94,
    sessionsDone: 215,
    creditsPerSession: 6,
    tags: ['HSK', 'Tones', 'Grammar', 'Beginner Friendly'],
    availability: ['Tue', 'Wed', 'Sat', 'Sun'],
    level: 'Beginner',
    gradientA: Color(0xFFA0E8E0),
    gradientB: Color(0xFF6FC8E0),
    isOnline: true,
    certifications: ['MTCSOL', 'HSK Chief Examiner'],
    responseTime: '< 2 hours',
    yearsExp: 6,
    testimonials: [
      TestimonialModel(
        studentName: '王小美',
        studentEmoji: '😊',
        stars: 5,
        text: '老师很有耐心，每次上课都能学到新的表达方式，强烈推荐！',
        textCn: '老师很有耐心，每次上课都能学到新的表达方式，强烈推荐！',
        date: '2025年5月',
        subject: '普通话基础',
      ),
      TestimonialModel(
        studentName: 'Alex B.',
        studentEmoji: '🙂',
        stars: 5,
        text:
            'James made tones feel manageable. I can finally distinguish all four tones after just 5 sessions!',
        textCn: 'James让声调变得可以掌握。仅仅5节课后，我终于能区分所有四个声调了！',
        date: 'Jun 2025',
        subject: 'HSK Prep',
      ),
    ],
  ),
  const TeacherModel(
    id: 't3',
    emoji: '👩‍🏫',
    name: 'Ms. Linda Li',
    nameCn: '李老师',
    subjects: 'Business English · Presentations',
    subjectsCn: '商务英语 · 演讲技巧',
    bio:
        'Former Fortune 500 corporate trainer turned full-time language coach. Specialises in high-stakes business communication, pitch prep, and executive presence in English.',
    bioCn: '前财富500强企业培训师，专注于高风险商务沟通、演讲准备和英语商务形象塑造。',
    rating: 4.9,
    reviewCount: 76,
    sessionsDone: 187,
    creditsPerSession: 10,
    tags: ['C-Suite', 'Presentations', 'Interviews', 'Email Writing'],
    availability: ['Mon', 'Wed', 'Fri'],
    level: 'Intermediate',
    gradientA: Color(0xFFC9B6FF),
    gradientB: Color(0xFF8B7CF6),
    isOnline: false,
    certifications: ['Cambridge CPE', 'MBA Communication'],
    responseTime: '< 3 hours',
    yearsExp: 12,
    testimonials: [
      TestimonialModel(
        studentName: 'Sophie T.',
        studentEmoji: '😊',
        stars: 5,
        text:
            'I nailed my C-suite presentation after just 3 prep sessions with Linda. She knows exactly what executives want to hear.',
        textCn: '经过Linda的3节备课，我顺利完成了高管演示。她非常了解高管们想听什么。',
        date: 'May 2025',
        subject: 'Business Presentations',
      ),
      TestimonialModel(
        studentName: 'Carlos M.',
        studentEmoji: '🙂',
        stars: 5,
        text:
            'My email quality transformed completely. Colleagues actually started commenting on how professional my writing became.',
        textCn: '我的邮件质量完全转变了。同事们开始评论我的写作变得多么专业。',
        date: 'Jun 2025',
        subject: 'Business Writing',
      ),
    ],
  ),
  const TeacherModel(
    id: 't4',
    emoji: '👨‍🏫',
    name: 'Mr. Kevin Zhao',
    nameCn: '赵老师',
    subjects: 'Math · Physics · Science',
    subjectsCn: '数学 · 物理 · 科学',
    bio:
        'PhD candidate in Applied Mathematics at Tsinghua. Makes abstract concepts visual and intuitive. Special strength in bridging Chinese and international curriculum standards.',
    bioCn: '清华大学应用数学博士候选人，擅长将抽象概念可视化，并桥接中英课程标准。',
    rating: 4.7,
    reviewCount: 53,
    sessionsDone: 134,
    creditsPerSession: 7,
    tags: ['GCSE', 'A-Level', 'Gaokao', 'SAT Math'],
    availability: ['Mon', 'Thu', 'Sat'],
    level: 'Advanced',
    gradientA: Color(0xFFFFE08A),
    gradientB: _C.amber,
    isOnline: true,
    certifications: ['PhD Applied Math (in progress)', 'IB Examiner'],
    responseTime: '< 4 hours',
    yearsExp: 4,
    testimonials: [
      TestimonialModel(
        studentName: 'Emma L.',
        studentEmoji: '😄',
        stars: 5,
        text:
            'Kevin explained calculus in a way no one else could. I went from failing to A grade in 6 weeks.',
        textCn: 'Kevin以任何人都无法做到的方式解释了微积分。我在6周内从不及格到A等级。',
        date: 'Jun 2025',
        subject: 'A-Level Math',
      ),
    ],
  ),
  const TeacherModel(
    id: 't5',
    emoji: '👩‍🏫',
    name: 'Ms. Amy Park',
    nameCn: '朴老师',
    subjects: 'Korean · Hangul · K-Culture',
    subjectsCn: '韩语 · 韩文 · 韩国文化',
    bio:
        'Seoul-native Korean teacher who blends pop-culture and K-dramas into practical, engaging lessons. Perfect for beginners and fans looking to understand their favourite content.',
    bioCn: '首尔本地韩语老师，将流行文化和韩剧融入实用有趣的课程，适合初学者和韩流爱好者。',
    rating: 4.8,
    reviewCount: 61,
    sessionsDone: 98,
    creditsPerSession: 7,
    tags: ['K-Pop', 'Drama Korean', 'Hangul', 'Beginner'],
    availability: ['Tue', 'Thu', 'Sun'],
    level: 'Beginner',
    gradientA: Color(0xFFFFB3D1),
    gradientB: Color(0xFFFF6FA6),
    isOnline: true,
    certifications: ['TOPIK Examiner', 'Seoul National Uni'],
    responseTime: '< 1 hour',
    yearsExp: 5,
    testimonials: [
      TestimonialModel(
        studentName: 'Mia S.',
        studentEmoji: '😊',
        stars: 5,
        text:
            'I can finally read Hangul and understand my K-dramas! Amy makes every lesson so much fun with drama clips and songs.',
        textCn: '我终于能读韩文并理解我的韩剧了！Amy用戏剧片段和歌曲让每节课都非常有趣。',
        date: 'Jun 2025',
        subject: 'Korean Basics',
      ),
    ],
  ),
  const TeacherModel(
    id: 't6',
    emoji: '👨‍🏫',
    name: 'Mr. Raj Patel',
    nameCn: '帕特尔老师',
    subjects: 'English · Creative Writing · Literature',
    subjectsCn: '英语 · 创意写作 · 文学',
    bio:
        'Published author and English Lit graduate from Oxford. Passionate about helping students find their unique voice in writing, from personal essays to short stories.',
    bioCn: '牛津大学英文学士，已出版作者，专注于帮助学生找到独特的写作声音，从个人文章到短篇故事。',
    rating: 4.6,
    reviewCount: 42,
    sessionsDone: 89,
    creditsPerSession: 9,
    tags: ['Creative Writing', 'Oxford', 'Essays', 'Literature'],
    availability: ['Wed', 'Fri', 'Sat'],
    level: 'Intermediate',
    gradientA: Color(0xFFB5E8C3),
    gradientB: Color(0xFF3FC6BD),
    isOnline: true,
    certifications: ['Oxford BA English', 'Published Author'],
    responseTime: '< 5 hours',
    yearsExp: 7,
    testimonials: [
      TestimonialModel(
        studentName: 'Isabella C.',
        studentEmoji: '😊',
        stars: 5,
        text:
            'Raj helped me transform my university application essay from generic to genuinely compelling. Got into my first-choice school!',
        textCn: 'Raj帮我将大学申请文章从普通改造为真正引人注目的作品。我考入了第一志愿学校！',
        date: 'Mar 2025',
        subject: 'Personal Essay',
      ),
    ],
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
//  FIND TEACHERS PAGE
// ═══════════════════════════════════════════════════════════════════════════════
class FindTeachersPage extends StatefulWidget {
  const FindTeachersPage({super.key});

  @override
  State<FindTeachersPage> createState() => _FindTeachersPageState();
}

class _FindTeachersPageState extends State<FindTeachersPage> {
  String _searchQuery = '';
  String _selectedSubject = 'All';
  String _selectedLevel = 'All Levels';
  String _selectedSort = 'Top Rated';
  bool _onlineOnly = false;

  final _subjects = [
    'All',
    'English',
    'Mandarin',
    'Korean',
    'Math',
    'Business',
    'Writing',
  ];
  final _levels = ['All Levels', 'Beginner', 'Intermediate', 'Advanced'];
  final _sorts = [
    'Top Rated',
    'Most Sessions',
    'Lowest Credits',
    'Fastest Reply',
  ];

  List<TeacherModel> get _filtered {
    var list = _kTeachers.where((t) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          t.name.toLowerCase().contains(q) ||
          t.subjects.toLowerCase().contains(q) ||
          t.tags.any((tag) => tag.toLowerCase().contains(q));
      final matchesSubject = _selectedSubject == 'All' ||
          t.subjects.contains(_selectedSubject) ||
          t.tags.any((tag) => tag.contains(_selectedSubject));
      final matchesLevel =
          _selectedLevel == 'All Levels' || t.level == _selectedLevel;
      final matchesOnline = !_onlineOnly || t.isOnline;
      return matchesSearch && matchesSubject && matchesLevel && matchesOnline;
    }).toList();

    switch (_selectedSort) {
      case 'Top Rated':
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case 'Most Sessions':
        list.sort((a, b) => b.sessionsDone.compareTo(a.sessionsDone));
      case 'Lowest Credits':
        list.sort((a, b) => a.creditsPerSession.compareTo(b.creditsPerSession));
      case 'Fastest Reply':
        list.sort((a, b) => a.responseTime.compareTo(b.responseTime));
    }
    return list;
  }

  void _openProfile(TeacherModel teacher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TeacherProfileSheet(teacher: teacher),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildFilters(),
            _buildResultsMeta(),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _C.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.line),
              ),
              child: const Center(
                child: Text('←', style: TextStyle(fontSize: 18, color: _C.ink)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find a Teacher',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _C.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '找到你的理想老师',
                  style: TextStyle(
                    fontSize: 12,
                    color: _C.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _onlineOnly = !_onlineOnly),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _onlineOnly ? _C.greenPale : _C.paper,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _onlineOnly ? _C.green : _C.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _onlineOnly ? _C.green : _C.inkSoft,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Online now',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _onlineOnly ? _C.green : _C.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search ───────────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _C.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.line),
          boxShadow: [
            BoxShadow(
              color: _C.violet.withValues(alpha: 0.06),
              blurRadius: 0.1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(
            fontSize: 14,
            color: _C.ink,
            fontWeight: FontWeight.w600,
          ),
          decoration: const InputDecoration(
            hintText: 'Search by name, subject, or keyword…',
            hintStyle: TextStyle(
              color: _C.inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Text('🔍', style: TextStyle(fontSize: 16)),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // ── Filters ──────────────────────────────────────────────────────────────────
  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _subjects.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final s = _subjects[i];
              final active = _selectedSubject == s;
              return GestureDetector(
                onTap: () => setState(() => _selectedSubject = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            colors: [_C.violet, _C.violetDeep],
                          )
                        : null,
                    color: active ? null : _C.paper,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? Colors.transparent : _C.line,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: _C.violet.withValues(alpha: 0.28),
                              blurRadius: 0.1,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : _C.inkSoft,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _DropdownFilter(
                label: _selectedLevel,
                icon: '🎓',
                options: _levels,
                onSelect: (v) => setState(() => _selectedLevel = v),
              ),
              const SizedBox(width: 10),
              _DropdownFilter(
                label: _selectedSort,
                icon: '↕️',
                options: _sorts,
                onSelect: (v) => setState(() => _selectedSort = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Results meta ─────────────────────────────────────────────────────────────
  Widget _buildResultsMeta() {
    final count = _filtered.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Row(
        children: [
          Text(
            '$count teacher${count == 1 ? '' : 's'} found',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _C.inkSoft,
            ),
          ),
          const SizedBox(width: 6),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _C.violetPale,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _C.violet,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Grid ─────────────────────────────────────────────────────────────────────
  Widget _buildGrid() {
    final teachers = _filtered;
    if (teachers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔭', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'No teachers match your filters.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _C.ink,
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() {
                _searchQuery = '';
                _selectedSubject = 'All';
                _selectedLevel = 'All Levels';
                _onlineOnly = false;
              }),
              child: const Text(
                'Clear all filters',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _C.violet,
                  decoration: TextDecoration.underline,
                  decorationColor: _C.violet,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 268,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: teachers.length,
      itemBuilder: (_, i) => _TeacherCard(
        teacher: teachers[i],
        onTap: () => _openProfile(teachers[i]),
      ),
    );
  }
}

// ─── Dropdown filter pill ──────────────────────────────────────────────────────
class _DropdownFilter extends StatelessWidget {
  final String label, icon;
  final List<String> options;
  final void Function(String) onSelect;

  const _DropdownFilter({
    required this.label,
    required this.icon,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _OptionsSheet(
            options: options,
            selected: label,
            onSelect: (v) {
              onSelect(v);
              Navigator.pop(context);
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _C.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.line),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _C.ink,
              ),
            ),
            const SizedBox(width: 4),
            const Text('▾', style: TextStyle(fontSize: 10, color: _C.inkSoft)),
          ],
        ),
      ),
    );
  }
}

class _OptionsSheet extends StatelessWidget {
  final List<String> options;
  final String selected;
  final void Function(String) onSelect;

  const _OptionsSheet({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.paper,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _C.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          ...options.map(
            (o) => GestureDetector(
              onTap: () => onSelect(o),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: selected == o ? _C.violetPale : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        o,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: selected == o ? _C.violet : _C.ink,
                        ),
                      ),
                    ),
                    if (selected == o)
                      const Text(
                        '✓',
                        style: TextStyle(
                          color: _C.violet,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Teacher card ─────────────────────────────────────────────────────────────
class _TeacherCard extends StatelessWidget {
  final TeacherModel teacher;
  final VoidCallback onTap;

  const _TeacherCard({required this.teacher, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _C.paper,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _C.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 0.1,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Card top gradient with avatar
            Container(
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [teacher.gradientA, teacher.gradientB],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Stack(
                children: [
                  // Decorative circle
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  // Online badge
                  if (teacher.isOnline)
                    Positioned(
                      top: 10,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _C.green,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Online',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: _C.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Avatar
                  Positioned(
                    bottom: -22,
                    left: 16,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [teacher.gradientA, teacher.gradientB],
                        ),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: teacher.gradientB.withValues(alpha: 0.4),
                            blurRadius: 0.1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          teacher.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Card body
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          teacher.name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: _C.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text('⭐', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 2),
                      Text(
                        teacher.rating.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _C.ink,
                        ),
                      ),
                      Text(
                        ' (${teacher.reviewCount})',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: _C.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    teacher.subjects,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _C.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: teacher.tags
                        .take(3)
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _C.violetPale,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: _C.violetDeep,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _C.amberPale,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '💎 ${teacher.creditsPerSession} credits',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFC77B1F),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_C.violet, _C.violetDeep],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _C.violet.withValues(alpha: 0.3),
                              blurRadius: 0.1,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Text(
                          'View Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TEACHER PROFILE BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════
class _TeacherProfileSheet extends StatefulWidget {
  final TeacherModel teacher;
  const _TeacherProfileSheet({required this.teacher});

  @override
  State<_TeacherProfileSheet> createState() => _TeacherProfileSheetState();
}

class _TeacherProfileSheetState extends State<_TeacherProfileSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.teacher;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _C.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [_buildHero(t), _buildStats(t), _buildTabs(t)],
              ),
            ),
          ),
          _buildBookingBar(t),
        ],
      ),
    );
  }

  // ── Hero ────────────────────────────────────────────────────────────────────
  Widget _buildHero(TeacherModel t) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.gradientA, t.gradientB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [t.gradientA, t.gradientB],
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: t.gradientB.withValues(alpha: 0.35),
                        blurRadius: 0.1,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(t.emoji, style: const TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (t.isOnline)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  _PulseGreen(),
                                  SizedBox(width: 5),
                                  Text(
                                    'Online',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        t.nameCn,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.subjects,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('⭐', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 3),
                          Text(
                            '${t.rating}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            ' · ${t.reviewCount} reviews',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats row ────────────────────────────────────────────────────────────────
  Widget _buildStats(TeacherModel t) {
    final items = [
      ('${t.sessionsDone}', 'Sessions'),
      ('${t.yearsExp} yrs', 'Experience'),
      (t.responseTime, 'Reply time'),
      ('${t.creditsPerSession}💎', 'Per session'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _C.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.line),
      ),
      child: Row(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Expanded(
            child: Container(
              decoration: i < items.length - 1
                  ? const BoxDecoration(
                      border: Border(right: BorderSide(color: _C.line)),
                    )
                  : null,
              child: Column(
                children: [
                  Text(
                    item.$1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _C.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _C.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Tabs ─────────────────────────────────────────────────────────────────────
  Widget _buildTabs(TeacherModel t) {
    return Column(
      children: [
        const SizedBox(height: 14),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: _C.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.line),
          ),
          child: TabBar(
            controller: _tabs,
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_C.violet, _C.violetDeep],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: _C.inkSoft,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.all(4),
            tabs: const [
              Tab(text: 'About'),
              Tab(text: 'Reviews'),
              Tab(text: 'Schedule'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 400,
          child: TabBarView(
            controller: _tabs,
            children: [
              _AboutTab(teacher: t),
              _ReviewsTab(teacher: t),
              _ScheduleTab(teacher: t),
            ],
          ),
        ),
      ],
    );
  }

  // ── Booking bar ──────────────────────────────────────────────────────────────
  Widget _buildBookingBar(TeacherModel t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: _C.paper,
        border: const Border(top: BorderSide(color: _C.line)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 0.1,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t.creditsPerSession} credits / session',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _C.ink,
                ),
              ),
              Text(
                '≈ ${(t.creditsPerSession * 1.2).toStringAsFixed(0)} USD per booking',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: _C.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.line),
              color: _C.paper,
            ),
            child: const Center(
              child: Text('💬', style: TextStyle(fontSize: 18)),
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_C.violet, _C.violetDeep],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _C.violet.withValues(alpha: 0.35),
                    blurRadius: 0.1,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Text(
                '📅  Book a Session',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── About tab ────────────────────────────────────────────────────────────────
class _AboutTab extends StatelessWidget {
  final TeacherModel teacher;
  const _AboutTab({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final t = teacher;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _C.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _C.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About me',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _C.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.bio,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: _C.ink,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  t.bioCn,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _C.inkSoft,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _C.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _C.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Certifications 🏅',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _C.ink,
                  ),
                ),
                const SizedBox(height: 10),
                ...t.certifications.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _C.violetPale,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text('🎓', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          c,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _C.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _C.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _C.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Specialties',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _C.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: t.tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_C.violetPale, Color(0xFFE8E2FF)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _C.line),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _C.violetDeep,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Reviews tab ─────────────────────────────────────────────────────────────
class _ReviewsTab extends StatelessWidget {
  final TeacherModel teacher;
  const _ReviewsTab({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final t = teacher;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF3DC), _C.amberPale],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.line),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      '${t.rating}',
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: _C.ink,
                        height: 1,
                      ),
                    ),
                    const Text(
                      '⭐⭐⭐⭐⭐',
                      style: TextStyle(fontSize: 14, letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${t.reviewCount} reviews',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _C.inkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [5, 4, 3, 2, 1].map((star) {
                      final pct = star == 5
                          ? 0.78
                          : star == 4
                              ? 0.16
                              : star == 3
                                  ? 0.04
                                  : 0.01;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Text(
                              '$star',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _C.inkSoft,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '★',
                              style: TextStyle(fontSize: 10, color: _C.amber),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6,
                                  backgroundColor: Colors.white,
                                  valueColor: const AlwaysStoppedAnimation(
                                    _C.amber,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${(pct * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _C.inkSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...t.testimonials.map((review) => _ReviewCard(review: review)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final TestimonialModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 0.1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.violetPale,
                ),
                child: Center(
                  child: Text(
                    review.studentEmoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.studentName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _C.ink,
                      ),
                    ),
                    Text(
                      '${review.subject} · ${review.date}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _C.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '⭐' * review.stars,
                style: const TextStyle(fontSize: 12, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '"${review.text}"',
            style: const TextStyle(
              fontSize: 13,
              color: _C.ink,
              height: 1.5,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (review.textCn != review.text) ...[
            const SizedBox(height: 6),
            Text(
              '"${review.textCn}"',
              style: const TextStyle(
                fontSize: 12,
                color: _C.inkSoft,
                height: 1.45,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _C.greenPale,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Text('👍', style: TextStyle(fontSize: 11)),
                    SizedBox(width: 4),
                    Text(
                      'Helpful',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _C.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _C.violetPale,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Verified Student ✓',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _C.violet,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Schedule tab ─────────────────────────────────────────────────────────────
class _ScheduleTab extends StatefulWidget {
  final TeacherModel teacher;
  const _ScheduleTab({required this.teacher});

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  String? _selectedDay;
  String? _selectedTime;

  static const _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _slots = [
    '9:00 AM',
    '10:00 AM',
    '11:00 AM',
    '2:00 PM',
    '3:00 PM',
    '4:00 PM',
    '7:00 PM',
    '8:00 PM',
  ];

  @override
  Widget build(BuildContext context) {
    final t = widget.teacher;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _C.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _C.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pick a day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _C.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _allDays.map((day) {
                    final available = t.availability.contains(day);
                    final selected = _selectedDay == day;
                    return GestureDetector(
                      onTap: available
                          ? () => setState(() {
                                _selectedDay = day;
                                _selectedTime = null;
                              })
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 40,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: selected
                              ? const LinearGradient(
                                  colors: [_C.violet, _C.violetDeep],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : null,
                          color: selected
                              ? null
                              : available
                                  ? _C.violetPale
                                  : const Color(0xFFF1EFFB),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: _C.violet.withValues(alpha: 0.3),
                                    blurRadius: 0.1,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              day,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : available
                                        ? _C.violetDeep
                                        : _C.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: available
                                    ? (selected ? Colors.white70 : _C.violet)
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedDay != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _C.paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _C.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available slots on $_selectedDay',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _C.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _slots.map((slot) {
                      final isBooked = slot == '10:00 AM' || slot == '3:00 PM';
                      final selected = _selectedTime == slot;
                      return GestureDetector(
                        onTap: isBooked
                            ? null
                            : () => setState(() => _selectedTime = slot),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: selected
                                ? const LinearGradient(
                                    colors: [_C.teal, Color(0xFF2DAAA1)],
                                  )
                                : null,
                            color: selected
                                ? null
                                : isBooked
                                    ? const Color(0xFFF1EFFB)
                                    : _C.tealPale,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? Colors.transparent
                                  : isBooked
                                      ? _C.line
                                      : _C.teal.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            slot,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : isBooked
                                      ? _C.inkSoft
                                      : const Color(0xFF1F9890),
                              decoration:
                                  isBooked ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          if (_selectedDay != null && _selectedTime != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _C.greenPale,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _C.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_selectedDay at $_selectedTime',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _C.ink,
                          ),
                        ),
                        const Text(
                          'Tap "Book a Session" below to confirm.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _C.inkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Pulse dot (green) ────────────────────────────────────────────────────────
class _PulseGreen extends StatefulWidget {
  const _PulseGreen();
  @override
  State<_PulseGreen> createState() => _PulseGreenState();
}

class _PulseGreenState extends State<_PulseGreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _scale = Tween(
      begin: 1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween(
      begin: 0.7,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.green.withValues(alpha: _opacity.value),
                ),
              ),
            ),
          ),
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _C.green,
            ),
          ),
        ],
      ),
    );
  }
}
