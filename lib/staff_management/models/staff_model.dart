import 'dart:typed_data';

import 'package:gd_college/models/user_session.dart';

import '../../widgets/increments.dart';

class StaffModel {

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

  String? netName;
  Uint8List? netData;
  String? netUrl;

  String? phdName;
  Uint8List? phdData;
  String? phdUrl;

  // Step 5: Course & Admission
  String? salary;
  String? designation;
  String? course;
  List<IncrementEntry> increments;
  DateTime? dateOfJoining;
  DateTime? dateOfRelieving;
  String staffId;

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

  String? appointmentLetterName;
  Uint8List? appointmentLetterData;
  String? appointmentLetterUrl;

  String? joiningLetterName;
  Uint8List? joiningLetterData;
  String? joiningLetterUrl;

  String? universityApprovalName;
  Uint8List? universityApprovalData;
  String? universityApprovalUrl;

  String? resignationLetterName;
  Uint8List? resignationLetterData;
  String? resignationLetterUrl;

  List<String> experienceCertificatesNames;
  List<Uint8List> experienceCertificateData;
  List<String> experienceCertificateUrls;

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

  StaffModel({
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
    this.appointmentLetterName,
    this.appointmentLetterData,
    this.appointmentLetterUrl,
    this.joiningLetterName,
    this.joiningLetterData,
    this.joiningLetterUrl,
    this.universityApprovalName,
    this.universityApprovalData,
    this.universityApprovalUrl,
    this.resignationLetterName,
    this.resignationLetterData,
    this.resignationLetterUrl,
    this.salary = '',
    this.increments = const [],
    this.staffId = '',
    this.dateOfJoining,
    this.dateOfRelieving,
    this.phdData,
    this.phdName,
    this.phdUrl,
    this.netData,
    this.netName,
    this.netUrl,
    this.experienceCertificatesNames = const [],
    this.experienceCertificateData = const [],
    this.experienceCertificateUrls = const [],
    this.otherFileData = const [],
    this.otherFileNames = const [],
    this.otherFileUrls = const [],
    this.designation = '',
    this.course,
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
      'net': netUrl,
      'phd': phdUrl,
      'designation': designation,
      'course': course,
      'staffId': staffId,
      'photoUrl': photoUrl,
      'scCertificateUrl': scCertificateUrl,
      'bcCertificateUrl': bcCertificateUrl,
      'appointmentLetterUrl': appointmentLetterUrl,
      'joiningLetterUrl': joiningLetterUrl,
      'universityApprovalUrl': universityApprovalUrl,
      'resignationLetterUrl': resignationLetterUrl,
      'otherFileUrls': otherFileUrls,
      'experienceCertificateUrls': experienceCertificateUrls,
      'salary': salary,
      'increments': increments.map((e) => {
        'date': e.date?.toIso8601String(),
        'amount': e.amount,
      }).toList(),
      'dateOfJoining': dateOfJoining?.toIso8601String(),
      'dateOfRelieving': dateOfRelieving?.toIso8601String(),
      'documentVersion': documentVersion,
      'isLocked': isLocked,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'createdBy': createdBy ?? UserSession().currentUser!.email,
      'lastUpdatedBy': UserSession().currentUser!.email,
    };
  }

  StaffModel clone() {
    return StaffModel(
      docId: docId,
      name: name, fatherName: fatherName, motherName: motherName,
      dob: dob, gender: gender, caste: caste,
      address: address, village: village, district: district,
      state: state, pin: pin, mobileNo1: mobileNo1, mobileNo2: mobileNo2,
      aadharNumber: aadharNumber, aadharUrl: aadharUrl, panCard: panCard, panUrl: panUrl, familyId: familyId,
      tenthUrl: tenthUrl, twelfthUrl: twelfthUrl, graduationUrl: graduationUrl,
      postGraduationUrl: postGraduationUrl, diplomaUrl: diplomaUrl,
      phdUrl: phdUrl, netUrl: netUrl, salary: salary, increments: List.from(increments),
      dateOfJoining: dateOfJoining, dateOfRelieving: dateOfRelieving,
      staffId: staffId,
      photoUrl: photoUrl,
      designation: designation,
      course: course,
      scCertificateUrl: scCertificateUrl,
      bcCertificateUrl: bcCertificateUrl,
      appointmentLetterUrl: appointmentLetterUrl,
      joiningLetterUrl: joiningLetterUrl,
      universityApprovalUrl: universityApprovalUrl,
      resignationLetterUrl: resignationLetterUrl,
      experienceCertificateUrls: List.from(experienceCertificateUrls),
      otherFileUrls: List.from(otherFileUrls),
      documentVersion: documentVersion, isLocked: isLocked,
      createdAt: createdAt, updatedAt: updatedAt,
      createdBy: createdBy, lastUpdatedBy: lastUpdatedBy,
    );
  }


  factory StaffModel.fromFirestore(String id, Map<String, dynamic> data) {
    return StaffModel(
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
      designation: data['designation'] ?? '',
      course: data['course'] ?? '',
      familyId: data['familyId'] ?? '',
      tenthUrl: data['tenth'] ?? '',
      twelfthUrl: data['twelfth'] ?? '',
      graduationUrl: data['graduation'] ?? '',
      postGraduationUrl: data['postGraduation'] ?? '',
      diplomaUrl: data['diploma'] ?? '',
      phdUrl: data['phdUrl'] ?? '',
      netUrl: data['netUrl'] ?? '',
      salary: data['salary'] ?? '',
      increments: (data['increments'] as List<dynamic>? ?? [])
          .map((e) => IncrementEntry(
        date: e['date'] != null ? DateTime.tryParse(e['date']) : null,
        amount: e['amount'] ?? '',
      )).toList(),
      dateOfJoining: data['dateOfJoining'] != null
          ? DateTime.tryParse(data['dateOfJoining'])
          : null,
      dateOfRelieving: data['dateOfRelieving'] != null
          ? DateTime.tryParse(data['dateOfRelieving'])
          : null,
      staffId: data['staffId'],
      photoUrl: data['photoUrl'],
      scCertificateUrl: data['scCertificateUrl'],
      bcCertificateUrl: data['bcCertificateUrl'],
      appointmentLetterUrl: data['appointmentLetterUrl'],
      joiningLetterUrl: data['joiningLetterUrl'],
      universityApprovalUrl: data['universityApprovalUrl'],
      resignationLetterUrl: data['resignationLetterUrl'],
      experienceCertificateUrls: List<String>.from(data['experienceCertificateUrls'] ?? []),
      otherFileUrls: List<String>.from(data['otherFileUrls'] ?? []),
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
