import 'package:flutter/material.dart';

import '../../../generated/l10n.dart';

enum MyOrderStatus {
  any('any'),
  pending('pending'),
  delivered('delivered'),
  processing('processing'),
  onHold('on-hold'),
  completed('completed'),
  cancelled('cancelled'),
  failed('failed'),

  ;

  const MyOrderStatus(this.status);
  final String status;

  String getName(BuildContext context) {
    switch (this) {
      case pending:
        return S.of(context).orderStatusPending;
      case delivered:
        return 'Delivered';
      case processing:
        return S.of(context).orderStatusProcessing;
      case onHold:
        return S.of(context).orderStatusOnHold;
      case completed:
        return S.of(context).orderStatusCompleted;
      case cancelled:
        return S.of(context).orderStatusCancelled;
      // case refunded:
      //   return S.of(context).orderStatusRefunded;
      case failed:
        return S.of(context).orderStatusFailed;
      default:
        return S.of(context).all;
    }
  }
}
