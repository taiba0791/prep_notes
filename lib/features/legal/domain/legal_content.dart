/// Text of the legal pages (Privacy, Terms, Refunds, Delivery, About,
/// Contact). Kept in one file so it's easy to review and translate.
///
/// ⚠️ TEMPLATE — not legal advice. Review it (ideally with a lawyer / CA),
/// and set [LegalInfo.operatorName] to the legal name used in your Razorpay
/// KYC before going live.
library;

/// Business details shown on the legal pages.
abstract final class LegalInfo {
  static const brand = 'PrepNotes';

  /// The person or business that runs PrepNotes — must match your KYC name.
  static const operatorName = 'Taiba Khwaja Shaikh';
  static const email = 'prep.notes247@gmail.com';
  static const country = 'India';
  static const lastUpdated = '7 October 2026';
  static const replyWithin = '2 working days';
  static const refundRequestDays = 7;
  static const deliveryHours = 24;
}

/// A heading with paragraphs and/or bullet points.
class LegalSection {
  const LegalSection(
    this.heading, {
    this.paragraphs = const [],
    this.bullets = const [],
  });

  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;
}

/// A whole page.
class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<LegalSection> sections;
}

abstract final class LegalContent {
  static const _b = LegalInfo.brand;
  static const _e = LegalInfo.email;

  // ── About ────────────────────────────────────────────────
  static const about = LegalDocument(
    title: 'About PrepNotes',
    intro:
        '$_b helps university students find exam-ready notes for their exact '
        'syllabus — organised by university, semester, subject and module.',
    sections: [
      LegalSection(
        'What we offer',
        bullets: [
          'Notes for sale, filed under your university, semester, subject and module '
              '(6 months of access each), or a whole-semester bundle.',
          'A free preview of the first pages, so you know what you are buying.',
          'The Resource Room: your private study locker for Drive links, YouTube '
              'videos and your own class notes (with a bundle or a subscription).',
          'A Study Zone with Pomodoro and stopwatch timers.',
          'Student Voice — tell us which notes or features you want next.',
        ],
      ),
      LegalSection(
        'Who runs PrepNotes',
        paragraphs: [
          '$_b is operated by ${LegalInfo.operatorName}, ${LegalInfo.country}. '
              'Questions? Write to $_e.',
        ],
      ),
    ],
  );

  // ── Privacy ──────────────────────────────────────────────
  static const privacy = LegalDocument(
    title: 'Privacy Policy',
    intro:
        'This policy explains what personal data $_b collects, why, and the '
        'choices you have. We aim to follow applicable Indian law, including '
        'the Digital Personal Data Protection Act, 2023.',
    sections: [
      LegalSection(
        'What we collect',
        bullets: [
          'Account details: your name, email address and, if you choose, a profile photo.',
          'Profile details you add: university and semester.',
          'Purchases: which notes you bought, order IDs, amounts and payment status. '
              'Card, UPI and bank details are handled by our payment partner Razorpay — '
              'we never see or store them.',
          'Activity in the app: notes you recently viewed, study sessions and feedback you submit.',
          'Resource Room content you save: links, titles and the files you upload. '
              'Only you can see them.',
          'Technical data: device and browser type, crash reports and basic usage '
              'statistics, to keep the app working and improve it.',
        ],
      ),
      LegalSection(
        'Why we use it',
        bullets: [
          'To create and secure your account and let you sign in.',
          'To sell you notes and give you access to what you bought.',
          'To show recently viewed notes, study statistics and your requests.',
          'To answer your questions, process refunds and prevent fraud.',
          'To fix problems and improve PrepNotes.',
        ],
      ),
      LegalSection(
        'Who we share it with',
        paragraphs: [
          'We do not sell your personal data. We share it only with service '
              'providers that run PrepNotes for us, under their own privacy terms:',
        ],
        bullets: [
          'Google Firebase (accounts, database, file storage, hosting, analytics, crash reports).',
          'Razorpay (payments).',
          'Authorities, when the law requires it.',
        ],
      ),
      LegalSection(
        'Where it is stored',
        paragraphs: [
          'Your data is stored on Google Cloud servers, mainly in India (Mumbai); '
              'some files are stored in Japan.',
        ],
      ),
      LegalSection(
        'How long we keep it',
        paragraphs: [
          'We keep your data while your account exists. When you delete your '
              'account (Profile → Delete account), we delete your profile, photo, '
              'study history, access records and Resource Room items. Order records '
              'are kept without your personal details, as needed for accounting and '
              'tax law.',
          'Resource Room items and uploads are deleted automatically when your '
              'Resource Room access ends (see the Terms).',
        ],
      ),
      LegalSection(
        'Your choices and rights',
        bullets: [
          'See and edit your details in Profile.',
          'Delete your account and data at any time from Profile.',
          'Ask us for a copy of your data, a correction, or to withdraw consent: write to $_e.',
          'Users under 18 should use PrepNotes with a parent or guardian’s permission.',
        ],
      ),
      LegalSection(
        'Cookies and local storage',
        paragraphs: [
          'We store small settings on your device — for example your light/dark '
              'theme and that you are signed in. We do not use advertising cookies.',
        ],
      ),
      LegalSection(
        'Security',
        paragraphs: [
          'We protect your data with access rules, encryption in transit and '
              'restricted access for staff. Paid notes can only be opened by '
              'people who bought them. No system is perfectly secure; please '
              'use a strong password.',
        ],
      ),
      LegalSection(
        'Changes and contact',
        paragraphs: [
          'If we change this policy we will update the date on this page. '
              'Questions or complaints: $_e.',
        ],
      ),
    ],
  );

  // ── Terms ────────────────────────────────────────────────
  static const terms = LegalDocument(
    title: 'Terms of Service',
    intro:
        'These terms are an agreement between you and ${LegalInfo.operatorName} '
        '("$_b", "we"). By creating an account or buying notes you agree to them.',
    sections: [
      LegalSection(
        'Your account',
        bullets: [
          'Give accurate details and keep your password safe.',
          'You are responsible for activity on your account.',
          'One account per person; accounts may not be shared or sold.',
        ],
      ),
      LegalSection(
        'Buying notes and bundles',
        bullets: [
          'Prices are shown in Indian Rupees (₹), including any applicable taxes.',
          'Payments are processed securely by Razorpay. A purchase is complete only '
              'when the payment is confirmed.',
          'A note gives you access for 6 months from the date of purchase. After '
              'that it locks; you can buy it again at the current price.',
          'A semester bundle gives you every note of that semester (including notes '
              'added during the period) and the Resource Room, for 6 months from the '
              'date of purchase.',
          'After payment, your notes appear in My Purchases on all your devices, '
              'with the date access ends.',
          'Refunds follow our Refund & Cancellation Policy.',
        ],
      ),
      LegalSection(
        'Resource Room and subscriptions',
        bullets: [
          'The Resource Room is a private space to save your own Google Drive and '
              'YouTube links and upload your own files (PDF or photos, up to 25 MB '
              'each and 200 MB in total). It is included with a semester bundle, or '
              'available as a subscription.',
          'Subscriptions (1, 3 or 6 months) renew automatically and are charged to '
              'the payment method you approve with Razorpay (for example UPI AutoPay '
              'or a card), at the price shown when you subscribed, until you cancel.',
          'You can cancel auto-renewal at any time in My Purchases. You keep access '
              'until the end of the period you have paid for; we do not refund '
              'partly used periods.',
          'When your Resource Room access ends (your bundle ends and you have no '
              'active subscription), the links and files you saved there are '
              'permanently deleted. We warn you in the app 14 days before. Keep '
              'your own copies of anything important.',
          'Only upload content you have the right to use. Do not upload anything '
              'illegal, harmful or that infringes others’ rights.',
        ],
      ),
      LegalSection(
        'What you may do with notes',
        paragraphs: [
          'When you buy notes you get a personal, non-transferable licence to read '
              'them for your own study. You may not copy, share, resell, upload, '
              'or distribute them, in whole or in part. Notes may carry your email '
              'as a watermark. Breaking these rules may lead to account suspension.',
        ],
      ),
      LegalSection(
        'Content',
        paragraphs: [
          'We work hard to keep notes accurate and matched to syllabuses, but '
              'syllabuses change and mistakes happen. Notes are a study aid, not a '
              'guarantee of exam results. Tell us about errors at $_e.',
          'Notes, designs and the PrepNotes name belong to us or our authors.',
        ],
      ),
      LegalSection(
        'Fair use',
        bullets: [
          'Do not try to access notes you have not bought, or break the app’s security.',
          'Do not upload harmful content or misuse Student Voice.',
          'Do not use bots or scrapers.',
        ],
      ),
      LegalSection(
        'Liability',
        paragraphs: [
          'PrepNotes is provided "as is". To the extent the law allows, our total '
              'liability for any claim is limited to the amount you paid for the '
              'notes concerned.',
        ],
      ),
      LegalSection(
        'Ending your account',
        paragraphs: [
          'You can delete your account at any time from Profile. We may suspend '
              'accounts that break these terms.',
        ],
      ),
      LegalSection(
        'Law and contact',
        paragraphs: [
          'These terms are governed by the laws of ${LegalInfo.country}. '
              'Questions: $_e.',
        ],
      ),
    ],
  );

  // ── Refunds ──────────────────────────────────────────────
  static const refund = LegalDocument(
    title: 'Refund & Cancellation Policy',
    intro:
        'Notes are digital and available immediately, so purchases are normally '
        'final. We will refund you in the cases below.',
    sections: [
      LegalSection(
        'You can get a refund if',
        bullets: [
          'You were charged twice for the same notes.',
          'Your payment succeeded but the notes did not appear in My Purchases '
              'within ${LegalInfo.deliveryHours} hours.',
          'The file is broken or does not open, and we cannot fix it within 3 working days.',
          'The notes are clearly different from their description (for example the '
              'wrong subject or university).',
        ],
      ),
      LegalSection(
        'No refund if',
        bullets: [
          'You changed your mind after the notes or bundle were unlocked.',
          'You bought the wrong notes even though the preview and description were correct.',
          'Your access period (6 months) has ended.',
          'A subscription period has already started. Cancel auto-renew before the '
              'next renewal date to avoid the next charge.',
        ],
      ),
      LegalSection(
        'How to ask',
        paragraphs: [
          'Email $_e within ${LegalInfo.refundRequestDays} days of the purchase '
              'with your order ID (from My Purchases) and the reason. We reply '
              'within ${LegalInfo.replyWithin}.',
        ],
      ),
      LegalSection(
        'How refunds are paid',
        paragraphs: [
          'Approved refunds go back to the original payment method through '
              'Razorpay, usually within 5–7 working days (your bank may take '
              'longer). Access to refunded notes or bundles is removed; for a '
              'refunded bundle, the Resource Room closes too.',
        ],
      ),
      LegalSection(
        'Cancellations',
        paragraphs: [
          'Subscriptions: cancel auto-renew any time in My Purchases; you are not '
              'charged again and keep access until the paid period ends. '
              'If you close the payment window before paying, nothing is charged. '
              'If money left your account but the order failed, it is returned '
              'automatically by Razorpay / your bank, usually within 5–7 working days.',
        ],
      ),
    ],
  );

  // ── Delivery ─────────────────────────────────────────────
  static const delivery = LegalDocument(
    title: 'Delivery Policy',
    intro: 'All PrepNotes products are digital. Nothing is shipped.',
    sections: [
      LegalSection(
        'How you receive your notes',
        bullets: [
          'Access is instant once your payment is confirmed — usually within a few seconds.',
          'Your notes appear in My Purchases and open in the PrepNotes viewer on web, '
              'Android and iOS, using the same account.',
          'Free notes are available straight away after you sign in.',
          'Paid notes and semester bundles stay available for 6 months from purchase; '
              'the end date is shown in My Purchases.',
          'The Resource Room opens instantly with a semester bundle or a subscription.',
        ],
      ),
      LegalSection(
        'If something goes wrong',
        paragraphs: [
          'If your notes are not in My Purchases within ${LegalInfo.deliveryHours} '
              'hours of a successful payment, email $_e with your order ID. '
              'If we cannot deliver them, you get a full refund.',
        ],
      ),
    ],
  );
}
