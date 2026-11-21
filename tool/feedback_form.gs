// Builds the reader feedback Google Form for طيّب قلبك.
// Paste into https://script.google.com (new project), then Run > createFeedbackForm.
// The form's links are printed in the execution log.

function createFeedbackForm() {
  var form = FormApp.create('رأيك في تطبيق طيّب قلبك');
  form.setDescription(
    'شكرًا إنك جربت التطبيق 🤍\n' +
    'الأسئلة سهلة وهتاخد منك دقيقتين بس، ورأيك هيفرق معانا جدًا.'
  );

  var features = [
    'قراءة حديث اليوم',
    'إشعار حديث اليوم (وصلك على الموبايل؟)',
    'كتابة تأمل أو رسالة على حديث',
    'مجتمع الحديث (قراءة مشاركات الناس)',
    'حفظ حاجة في المفضلة',
    'مشاركة حديث أو مشاركة كصورة',
    'الحفظ (المراجعة والتسميع)',
    'رحلتي (النقاط والتقدم)',
    'إنشاء الحساب وكود التأكيد اللي بيوصل على الإيميل',
    'نسيت كلمة المرور (استرجاعها بكود على الإيميل)'
  ];

  // --- جربت إيه؟ ---
  form.addSectionHeaderItem().setTitle('جربت إيه؟');

  form.addGridItem()
    .setTitle('لكل ميزة من دول، اختار اللي حصل معاك')
    .setRows(features)
    .setColumns(['جربتها وشغالة كويس', 'جربتها بس فيها مشكلة', 'لسه مجربتهاش'])
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('لو فيه ميزة فيها مشكلة، احكيلنا حصل إيه باختصار');

  // --- الإشعارات ---
  form.addPageBreakItem().setTitle('الإشعارات');

  form.addMultipleChoiceItem()
    .setTitle('إشعار حديث اليوم بيوصلك؟')
    .setChoiceValues(['أيوه، كل يوم', 'ساعات بيوصل وساعات لأ', 'مبيوصلش خالص', 'قفلت الإشعارات'])
    .setRequired(true);

  // --- رأيك العام ---
  form.addPageBreakItem().setTitle('رأيك العام');

  form.addScaleItem()
    .setTitle('التطبيق سهل في الاستخدام؟')
    .setBounds(1, 5)
    .setLabels('صعب', 'سهل جدًا')
    .setRequired(true);

  form.addScaleItem()
    .setTitle('شكل التطبيق عاجبك؟')
    .setBounds(1, 5)
    .setLabels('مش عاجبني', 'عاجبني جدًا')
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('التطبيق كان سريع ولا بيهنج؟')
    .setChoiceValues(['سريع', 'عادي', 'بطيء أو بيقفل لوحده'])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('أكتر ميزة عجبتك؟')
    .setChoiceValues([
      'حديث اليوم',
      'الإشعارات',
      'كتابة التأمل',
      'مجتمع الحديث',
      'المفضلة',
      'المشاركة كصورة',
      'الحفظ',
      'رحلتي'
    ])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('هتفضل تستخدم التطبيق؟')
    .setChoiceValues(['أكيد', 'يمكن', 'غالبًا لأ'])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('ترشحه لحد من صحابك أو أهلك؟')
    .setChoiceValues(['أيوه', 'يمكن', 'لأ'])
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('فيه حاجة نفسك تتضاف أو تتغير؟');

  form.setConfirmationMessage('شكرًا جدًا على وقتك 🤍 رأيك وصلنا.');

  Logger.log('رابط الفورم للناس: ' + form.getPublishedUrl());
  Logger.log('رابط التعديل: ' + form.getEditUrl());
}
