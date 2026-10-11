class NigerianBank {
  final String name;
  final String code;
  final String logo;
  final String? androidPackage;
  final String? iosScheme;
  final String? iosAppStoreId;

  const NigerianBank({
    required this.name,
    required this.code,
    required this.logo,
    this.androidPackage,
    this.iosScheme,
    this.iosAppStoreId,
  });
}

class NigerianBanks {
  static const List<NigerianBank> banks = [
    // ── Tier 1 Banks ──────────────────────────────────────────────────────────
    NigerianBank(
      name: 'Access Bank',
      code: '044',
      logo: 'assets/images/banks/access.png',
      // Access More (Nigeria) — com.accessbank.nextgen
      // Previously com.accessbank.accessbankapp was Ghana
      androidPackage: 'com.accessbank.nextgen',
      iosScheme: 'accessmore://',
      iosAppStoreId: '1574773672',
    ),
    NigerianBank(
      name: 'First Bank of Nigeria',
      code: '011',
      logo: 'assets/images/banks/firstbank.png',
      androidPackage: 'com.firstbank.firstmobile',
      iosScheme: 'firstmobile://',
      iosAppStoreId: '968715878',
    ),
    NigerianBank(
      name: 'GTBank (GTWorld)',
      code: '058',
      logo: 'assets/images/banks/gtbank.png',
      // GTWorld Nigeria — com.gtbank.gtworldv1
      androidPackage: 'com.gtbank.gtworldv1',
      iosScheme: 'gtworld://',
      iosAppStoreId: '1456950275',
    ),
    NigerianBank(
      name: 'UBA',
      code: '033',
      logo: 'assets/images/banks/uba.png',
      // UBA Mobile App Nigeria — com.ubanquity.redd.uba
      androidPackage: 'com.ubanquity.redd.uba',
      iosScheme: 'ubamobile://',
      iosAppStoreId: '1524316986',
    ),
    NigerianBank(
      name: 'Zenith Bank',
      code: '057',
      logo: 'assets/images/banks/zenith.png',
      // Zenith Bank Nigeria — com.zenithBank.eazymoney
      androidPackage: 'com.zenithBank.eazymoney',
      iosScheme: 'zenithmobile://',
      iosAppStoreId: '1459635031',
    ),

    // ── Fintechs / Neobanks ───────────────────────────────────────────────────
    NigerianBank(
      name: 'Kuda Bank',
      code: '090267',
      logo: 'assets/images/banks/kuda.png',
      androidPackage: 'com.kudabank.app',
      iosScheme: 'kuda://',
      iosAppStoreId: '1483960756',
    ),
    NigerianBank(
      name: 'OPay',
      code: '999992',
      logo: 'assets/images/banks/opay.png',
      androidPackage: 'team.opay.pay',
      iosScheme: 'opay://',
      iosAppStoreId: '1463870188',
    ),
    NigerianBank(
      name: 'PalmPay',
      code: '999991',
      logo: 'assets/images/banks/palmpay.png',
      androidPackage: 'com.transsnet.palmpay',
      iosScheme: 'palmpay://',
      iosAppStoreId: '1479679482',
    ),
    NigerianBank(
      name: 'Moniepoint',
      code: '090405',
      logo: 'assets/images/banks/moniepoint.png',
      // Moniepoint Personal Banking Nigeria
      androidPackage: 'com.moniepoint.personal',
      iosScheme: 'moniepoint://',
      iosAppStoreId: '1644781442',
    ),

    // ── Tier 2 / Commercial Banks ─────────────────────────────────────────────
    NigerianBank(
      name: 'Fidelity Bank',
      code: '070',
      logo: 'assets/images/banks/fidelity.png',
      androidPackage: 'com.fidelity.fidelitymobile',
      iosScheme: 'fidelity://',
      iosAppStoreId: '1456079944',
    ),
    NigerianBank(
      name: 'Union Bank',
      code: '032',
      logo: 'assets/images/banks/union.png',
      androidPackage: 'com.unionbankng.unionmobile',
      iosScheme: 'unionmobile://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'Stanbic IBTC',
      code: '221',
      logo: 'assets/images/banks/stanbic.png',
      androidPackage: 'com.stanbic.stanbicmobile',
      iosScheme: 'stanbicibtc://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'Sterling Bank',
      code: '232',
      logo: 'assets/images/banks/sterling.png',
      androidPackage: 'com.sterling.onepay',
      iosScheme: 'sterlingmobile://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'Polaris Bank',
      code: '076',
      logo: 'assets/images/banks/polaris.png',
      androidPackage: 'com.polaris.vurba',
      iosScheme: 'polarisbank://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'Wema Bank (ALAT)',
      code: '035',
      logo: 'assets/images/banks/wema.png',
      androidPackage: 'com.alat.app',
      iosScheme: 'alat://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'FCMB',
      code: '214',
      logo: 'assets/images/banks/fcmb.png',
      androidPackage: 'com.fcmb.mobile.mobilebanking',
      iosScheme: 'fcmbmobile://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'Ecobank Nigeria',
      code: '050',
      logo: 'assets/images/banks/ecobank.png',
      // Ecobank Nigeria specific package
      androidPackage: 'com.ecobank.mobile.ng',
      iosScheme: 'ecobankmobile://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'Keystone Bank',
      code: '082',
      logo: 'assets/images/banks/keystone.png',
      androidPackage: 'com.keystone.mobile',
      iosScheme: 'keystonebank://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'Unity Bank',
      code: '215',
      logo: 'assets/images/banks/unity.png',
      androidPackage: 'com.unitybank.mobile',
      iosScheme: 'unitybank://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'Providus Bank',
      code: '101',
      logo: 'assets/images/banks/providus.png',
      androidPackage: 'com.providusbank.mobile',
      iosScheme: 'providusbank://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'Jaiz Bank',
      code: '301',
      logo: 'assets/images/banks/jaiz.png',
      androidPackage: 'com.jaiz.mobile',
      iosScheme: 'jaizbank://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'Titan Trust Bank',
      code: '102',
      logo: 'assets/images/banks/titan.png',
      androidPackage: 'com.titantrustbank.mobile',
      iosScheme: 'titantrust://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'Globus Bank',
      code: '103',
      logo: 'assets/images/banks/globus.png',
      androidPackage: 'com.globusbank.mobile',
      iosScheme: 'globusbank://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'TAJ Bank',
      code: '302',
      logo: 'assets/images/banks/taj.png',
      androidPackage: 'com.tajbank.mobile',
      iosScheme: 'tajbank://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'VFD Microfinance Bank',
      code: '090110',
      logo: 'assets/images/banks/vfd.png',
      androidPackage: 'com.vbank.vfd',
      iosScheme: 'vbank://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'Carbon',
      code: '090259',
      logo: 'assets/images/banks/carbon.png',
      androidPackage: 'ng.getcarbon.app',
      iosScheme: 'carbon://',
      iosAppStoreId: null,
    ),
    NigerianBank(
      name: 'Rubies Bank',
      code: '090175',
      logo: 'assets/images/banks/rubies.png',
      androidPackage: 'com.rubiesbank.mobile',
      iosScheme: 'rubiesbank://',
      iosAppStoreId: null,
    ),
  ];
}
