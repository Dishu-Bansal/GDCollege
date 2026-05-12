import 'dart:typed_data';

import 'package:gd_college/models/user_session.dart';

class StudentModel {

  // Firestore document ID (populated after fetch)
  String? docId;

  // Step 1: Personal Info
  String name;
  String fatherName;
  String motherName;
  DateTime? dob;
  String gender;
  String caste;

  // Step 2: Address
  String address;
  String village;
  String district;
  String state;
  String pin;
  String mobileNo1;
  String mobileNo2;

  // Step 3: IDs & Certificates
  String aadharNumber;
  String panCard;
  String familyId;

  // Step 4: Educational Qualifications
  String? tenthName;
  Uint8List? tenthData;
  String? tenthUrl;

  String? twelfthName;
  Uint8List? twelfthData;
  String? twelfthUrl;

  String? graduationName;
  Uint8List? graduationData;
  String? graduationUrl;

  String? postGraduationName;
  Uint8List? postGraduationData;
  String? postGraduationUrl;

  String? diplomaName;
  Uint8List? diplomaData;
  String? diplomaUrl;

  // Step 5: Course & Admission
  String nameOfCourse;
  int? yearOfAdmission;
  String placementDetails;
  String feeDetails1stYear;
  String feeDetails2ndYear;
  String fineIfAny;
  String examFee;
  String studentId;

  // File paths (local) or Firebase URLs
  String? photoName;
  Uint8List? photoData;
  String? photoUrl;
  String? aadharName;
  Uint8List? aadharData;
  String? aadharUrl;
  String? panName;
  Uint8List? panData;
  String? panUrl;
  String? scCertificateName;
  Uint8List? scCertificateData;
  String? scCertificateUrl;
  String? bcCertificateName;
  Uint8List? bcCertificateData;
  String? bcCertificateUrl;
  String? sportsCertificateName;
  Uint8List? sportsCertificateData;
  String? sportsCertificateUrl;
  List<String> otherFileNames;
  List<Uint8List> otherFileData;
  List<String> otherFileUrls;

  // Metadata
  int documentVersion;
  bool isLocked;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? createdBy;
  String? lastUpdatedBy;

  StudentModel({
    this.docId,
    this.name = '',
    this.fatherName = '',
    this.motherName = '',
    this.dob,
    this.gender = '',
    this.caste = '',
    this.address = '',
    this.village = '',
    this.district = '',
    this.state = '',
    this.pin = '',
    this.mobileNo1 = '',
    this.mobileNo2 = '',
    this.aadharNumber = '',
    this.panCard = '',
    this.familyId = '',
    this.nameOfCourse = '',
    this.yearOfAdmission,
    this.placementDetails = '',
    this.feeDetails1stYear = '',
    this.feeDetails2ndYear = '',
    this.fineIfAny = '',
    this.examFee = '',
    this.studentId = '',
    this.tenthData,
    this.tenthName,
    this.tenthUrl,
    this.twelfthData,
    this.twelfthName,
    this.twelfthUrl,
    this.graduationData,
    this.graduationName,
    this.graduationUrl,
    this.postGraduationData,
    this.postGraduationName,
    this.postGraduationUrl,
    this.diplomaData,
    this.diplomaName,
    this.diplomaUrl,
    this.aadharData,
    this.aadharName,
    this.aadharUrl,
    this.panData,
    this.panName,
    this.panUrl,
    this.photoName,
    this.photoData,
    this.photoUrl,
    this.scCertificateName,
    this.scCertificateData,
    this.scCertificateUrl,
    this.bcCertificateName,
    this.bcCertificateData,
    this.bcCertificateUrl,
    this.sportsCertificateName,
    this.sportsCertificateData,
    this.sportsCertificateUrl,
    this.otherFileNames = const [],
    this.otherFileData = const [],
    this.otherFileUrls = const [],
    this.documentVersion = 1,
    this.isLocked = false,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.lastUpdatedBy,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'fatherName': fatherName,
      'motherName': motherName,
      'dob': dob?.toIso8601String(),
      'gender': gender,
      'caste': caste,
      'address': address,
      'village': village,
      'district': district,
      'state': state,
      'pin': pin,
      'mobileNo1': mobileNo1,
      'mobileNo2': mobileNo2,
      'aadharNumber': aadharNumber,
      'aadharurl':aadharUrl,
      'panCard': panCard,
      'panurl': panUrl,
      'familyId': familyId,
      'tenth': tenthUrl,
      'twelfth': twelfthUrl,
      'graduation': graduationUrl,
      'postGraduation': postGraduationUrl,
      'diploma': diplomaUrl,
      'nameOfCourse': nameOfCourse,
      'yearOfAdmission': yearOfAdmission,
      'placementDetails': placementDetails,
      'feeDetails1stYear': feeDetails1stYear,
      'feeDetails2ndYear': feeDetails2ndYear,
      'fineIfAny': fineIfAny,
      'examFee': examFee,
      'studentId': studentId,
      'photoUrl': photoUrl,
      'scCertificateUrl': scCertificateUrl,
      'bcCertificateUrl': bcCertificateUrl,
      'sportsCertificateUrl': sportsCertificateUrl,
      'otherFileUrls': otherFileUrls,
      'documentVersion': documentVersion,
      'isLocked': isLocked,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'createdBy': createdBy ?? UserSession().currentUser!.email,
      'lastUpdatedBy': UserSession().currentUser!.email,
    };
  }

  StudentModel clone() {
    return StudentModel(
      docId: docId,
      name: name, fatherName: fatherName, motherName: motherName,
      dob: dob, gender: gender, caste: caste,
      address: address, village: village, district: district,
      state: state, pin: pin, mobileNo1: mobileNo1, mobileNo2: mobileNo2,
      aadharNumber: aadharNumber, aadharUrl: aadharUrl, panCard: panCard, panUrl: panUrl, familyId: familyId,
      tenthUrl: tenthUrl, twelfthUrl: twelfthUrl, graduationUrl: graduationUrl,
      postGraduationUrl: postGraduationUrl, diplomaUrl: diplomaUrl,
      nameOfCourse: nameOfCourse, yearOfAdmission: yearOfAdmission,
      placementDetails: placementDetails,
      feeDetails1stYear: feeDetails1stYear,
      feeDetails2ndYear: feeDetails2ndYear,
      fineIfAny: fineIfAny, examFee: examFee, studentId: studentId,
      photoUrl: photoUrl,
      scCertificateUrl: scCertificateUrl,
      bcCertificateUrl: bcCertificateUrl,
      sportsCertificateUrl: sportsCertificateUrl,
      otherFileUrls: List.from(otherFileUrls),
      documentVersion: documentVersion, isLocked: isLocked,
      createdAt: createdAt, updatedAt: updatedAt,
      createdBy: createdBy, lastUpdatedBy: lastUpdatedBy,
    );
  }


  factory StudentModel.fromFirestore(String id, Map<String, dynamic> data) {
    return StudentModel(
      docId: id,
      name: data['name'] ?? '',
      fatherName: data['fatherName'] ?? '',
      motherName: data['motherName'] ?? '',
      dob: data['dob'] != null ? DateTime.tryParse(data['dob']) : null,
      gender: data['gender'] ?? '',
      caste: data['caste'] ?? '',
      address: data['address'] ?? '',
      village: data['village'] ?? '',
      district: data['district'] ?? '',
      state: data['state'] ?? '',
      pin: data['pin'] ?? '',
      mobileNo1: data['mobileNo1'] ?? '',
      mobileNo2: data['mobileNo2'] ?? '',
      aadharNumber: data['aadharNumber'] ?? '',
      aadharUrl: data['aadharurl'] ?? '',
      panCard: data['panCard'] ?? '',
      panUrl: data['panurl'] ?? '',
      familyId: data['familyId'] ?? '',
      tenthUrl: data['tenth'] ?? '',
      twelfthUrl: data['twelfth'] ?? '',
      graduationUrl: data['graduation'] ?? '',
      postGraduationUrl: data['postGraduation'] ?? '',
      diplomaUrl: data['diploma'] ?? '',
      nameOfCourse: data['nameOfCourse'] ?? '',
      yearOfAdmission: data['yearOfAdmission'],
      placementDetails: data['placementDetails'] ?? '',
      feeDetails1stYear: data['feeDetails1stYear'] ?? '',
      feeDetails2ndYear: data['feeDetails2ndYear'] ?? '',
      fineIfAny: data['fineIfAny'] ?? '',
      examFee: data['examFee'] ?? '',
      studentId: data['studentId'] ?? '',
      photoUrl: data['photoUrl'],
      scCertificateUrl: data['scCertificateUrl'],
      bcCertificateUrl: data['bcCertificateUrl'],
      sportsCertificateUrl: data['sportsCertificateUrl'],
      otherFileUrls: List<String>.from(data['otherFileUrls'] ?? []),
      otherFileNames: const [],
      documentVersion: data['documentVersion'] ?? 1,
      isLocked: data['isLocked'] ?? false,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'])
          : null,
      updatedAt: data['updatedAt'] != null
          ? DateTime.tryParse(data['updatedAt'])
          : null,
      createdBy: data['createdBy'] ?? '',
      lastUpdatedBy: data['lastUpdatedBy'] ?? '',
    );
  }
}
