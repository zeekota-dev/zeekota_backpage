ZeeKotaBackpage = ZeeKotaBackpage or {}

ZeeKotaBackpage.Resource = GetCurrentResourceName()
ZeeKotaBackpage.Events = {
    CallbackRequest = 'zeekota_backpage:server:callback',
    CallbackResponse = 'zeekota_backpage:client:callbackResponse',
    OpenPhoneFromItem = 'zeekota_backpage:client:openPhoneFromItem',
    OpenAdmin = 'zeekota_backpage:client:openAdmin',
    ForceClose = 'zeekota_backpage:client:forceClose',
    Notify = 'zeekota_backpage:client:notify',
    SyncState = 'zeekota_backpage:client:syncState',
    NewRequest = 'zeekota_backpage:client:newRequest',
    RequestUpdated = 'zeekota_backpage:client:requestUpdated',
    MeetupStarted = 'zeekota_backpage:client:meetupStarted',
    MeetupEnded = 'zeekota_backpage:client:meetupEnded',
    AdminData = 'zeekota_backpage:client:adminData',
    DealerLive = 'zeekota_backpage:server:dealerLive',
    DealerOffline = 'zeekota_backpage:server:dealerOffline',
    SaleCompleted = 'zeekota_backpage:server:saleCompleted',
    ClientGained = 'zeekota_backpage:server:clientGained',
    ReputationChanged = 'zeekota_backpage:server:reputationChanged'
}

ZeeKotaBackpage.RequestState = {
    Pending = 'pending',
    Accepted = 'accepted',
    Declined = 'declined',
    Expired = 'expired',
    Completed = 'completed',
    Cancelled = 'cancelled',
    Failed = 'failed'
}

ZeeKotaBackpage.MeetupState = {
    Traveling = 'traveling',
    Nearby = 'nearby',
    Interacting = 'interacting',
    Completed = 'completed',
    Failed = 'failed'
}

ZeeKotaBackpage.LogCategory = {
    Transaction = 'transaction',
    Client = 'client',
    Sample = 'sample',
    Meetup = 'meetup',
    Admin = 'admin',
    Config = 'config',
    Suspicious = 'suspicious',
    Error = 'error'
}
