Config = Config or {}

Config.ResourceName = 'zeekota_backpage'
Config.Framework = 'esx'
Config.Inventory = 'ox_inventory'
Config.Locale = 'en'
Config.Debug = false

Config.RequiredItem = 'burnerphone'

Config.Database = {
    Prefix = 'zeekota_backpage',
    Version = 1,
    SeedDefaults = true,
    CleanupIntervalMinutes = 30,
    MessageRetentionDays = 30,
    MaxConversationMessages = 80
}

Config.Admin = {
    Command = 'zeekotabackpageadmin',
    Aliases = { 'backpageadmin', 'zkbackpageadmin', 'zkadmin' },
    Groups = {
        admin = true,
        superadmin = true
    }
}

Config.Phone = {
    Prop = 'prop_npc_phone_02',
    Bone = 28422,
    Offset = { x = 0.0, y = 0.0, z = 0.0 },
    Rotation = { x = 0.0, y = 0.0, z = 0.0 },
    Animations = {
        Pullout = { dict = 'cellphone@', name = 'cellphone_text_in', duration = 850, flag = 49 },
        Hold = { dict = 'cellphone@', name = 'cellphone_text_read_base', duration = -1, flag = 49 },
        Tap = { dict = 'cellphone@', name = 'cellphone_text_read_base', duration = 800, flag = 49 },
        Putaway = { dict = 'cellphone@', name = 'cellphone_text_out', duration = 750, flag = 49 }
    },
    DisableControls = { 1, 2, 24, 25, 37, 44, 45, 140, 141, 142, 143, 257, 263, 264 },
    CloseControls = { 177, 200, 202, 322 },
    CloseOnInvalidState = true
}

Config.BlockingStates = {
    Dead = true,
    Cuffed = true,
    Swimming = true,
    Falling = true,
    Ragdoll = true,
    Vehicle = false
}

Config.Interaction = {
    Type = 'zeekota',
    Key = 38,
    KeyLabel = 'E',
    Distance = 2.0,
    PromptDistance = 2.7,
    TargetSupport = true,
    TargetResource = 'ox_target',
    Text = 'Speak With Customer'
}

Config.Payment = {
    Type = 'account',
    Account = 'black_money',
    Item = 'money',
    SocietyAccount = nil
}

Config.Session = {
    RequireDrugInventory = true,
    MinFirstRequestDelay = 30,
    MaxFirstRequestDelay = 60,
    MinRequestDelay = 30,
    MaxRequestDelay = 60,
    FailedRequestRetryDelay = 15,
    MaxSimultaneousRequests = 8,
    Duration = 2700,
    Cooldown = 600,
    MaxPendingMeetups = 1,
    RequestExpiration = 600,
    ExistingClientChance = 45,
    NewClientChance = 45,
    NoRequestChance = 0,
    RequiredPolice = 0,
    PoliceJobs = { 'police', 'sheriff', 'state' },
    AllowInVehicles = false,
    AllowInInteriors = true,
    PauseDuringMeetup = false,
    AllowEndWithMeetup = true,
    ProhibitedAreas = {},
    AreaModifiers = {}
}

Config.Meetups = {
    OneActiveMeetup = true,
    Timeout = 780,
    MinDistance = 85.0,
    MaxDistance = 1800.0,
    ArrivalDistance = 45.0,
    InteractionDistance = 2.0,
    RevealMarker = false,
    Blip = {
        Enabled = true,
        Sprite = 280,
        Color = 38,
        Scale = 0.78,
        ShortRange = false,
        Route = true
    },
    Customer = {
        Protect = true,
        FreezeWhileWaiting = true,
        CleanupDelay = 6500,
        IdleAnimations = {
            { dict = 'amb@world_human_smoking@male@male_a@idle_a', name = 'idle_c', flag = 1 },
            { dict = 'amb@world_human_hang_out_street@male_b@idle_a', name = 'idle_b', flag = 1 },
            { dict = 'amb@world_human_stand_mobile@male@text@idle_a', name = 'idle_a', flag = 1 }
        }
    },
    Locations = {
        { id = 'vespucci_alley', label = 'Vespucci Service Alley', x = -1217.74, y = -1247.87, z = 7.03, heading = 109.0, area = 'Vespucci', enabled = true, risk = 20 },
        { id = 'strawberry_lot', label = 'Strawberry Back Lot', x = 308.78, y = -1284.43, z = 30.58, heading = 88.0, area = 'Strawberry', enabled = true, risk = 30 },
        { id = 'mirror_park_pullout', label = 'Mirror Park Pullout', x = 1185.77, y = -418.11, z = 67.95, heading = 257.0, area = 'Mirror Park', enabled = true, risk = 16 },
        { id = 'del_perro_service', label = 'Del Perro Service Lane', x = -1503.52, y = -401.22, z = 41.21, heading = 224.0, area = 'Del Perro', enabled = true, risk = 22 },
        { id = 'sandy_liquor', label = 'Sandy Shores Side Street', x = 1956.44, y = 3747.74, z = 32.34, heading = 34.0, area = 'Sandy Shores', enabled = true, risk = 28 },
        { id = 'grapeseed_diner', label = 'Grapeseed Diner Lot', x = 1698.12, y = 4922.91, z = 42.07, heading = 326.0, area = 'Grapeseed', enabled = true, risk = 18 },
        { id = 'little_seoul_lot', label = 'Little Seoul Lot', x = -701.2, y = -879.44, z = 23.69, heading = 178.0, area = 'Little Seoul', enabled = true, risk = 26 },
        { id = 'davis_court', label = 'Davis Court Cut', x = 89.31, y = -1912.16, z = 21.06, heading = 141.0, area = 'Davis', enabled = true, risk = 36 }
    }
}

Config.Animations = {
    Greeting = { dict = 'gestures@m@standing@casual', name = 'gesture_hello', duration = 1300, flag = 48 },
    Handoff = { dict = 'mp_common', name = 'givetake1_a', duration = 1800, flag = 49 },
    Money = { dict = 'mp_common', name = 'givetake1_b', duration = 1800, flag = 49 },
    Inspect = { dict = 'amb@world_human_drug_dealer_hard@male@base', name = 'base', duration = 2400, flag = 1 },
    Reject = { dict = 'gestures@m@standing@casual', name = 'gesture_no_way', duration = 1400, flag = 48 },
    Nervous = { dict = 'amb@world_human_stand_mobile@male@text@idle_a', name = 'idle_a', duration = 2600, flag = 1 },
    WalkAway = { dict = 'move_m@casual@d', name = 'walk', duration = 1000, flag = 1 }
}

Config.ClientAcquisition = {
    BaseChance = 18,
    SuccessfulSaleBonus = 16,
    SampleBonus = 22,
    ExtraUnitBonus = 4,
    MaxExtraBonus = 14,
    ReputationDivisor = 80,
    CorrectRequestBonus = 8,
    FastArrivalSeconds = 180,
    FastArrivalBonus = 8,
    LateArrivalPenalty = 10,
    RejectionPenalty = 8,
    ReferralBonus = 6,
    MinChance = 2,
    MaxChance = 85,
    RevealExactChance = false
}

Config.Reputation = {
    Starting = 0,
    Sale = 3,
    ClientGained = 12,
    Sample = 1,
    FailedMeetup = -4,
    DeclinedRequest = -1,
    Max = 10000,
    Min = -500
}

Config.Loyalty = {
    Sale = 8,
    Sample = 10,
    ExtraUnit = 3,
    FailedMeetup = -12,
    DeclinedRequest = -4,
    Max = 1000,
    Min = 0,
    Tiers = {
        { id = 'new_contact', label = 'New Contact', loyalty = 0, priceMultiplier = 1.0, quantityMultiplier = 1.0, requestWeight = 1.0 },
        { id = 'returning', label = 'Returning Customer', loyalty = 35, priceMultiplier = 1.03, quantityMultiplier = 1.08, requestWeight = 1.15 },
        { id = 'regular', label = 'Regular', loyalty = 90, priceMultiplier = 1.07, quantityMultiplier = 1.18, requestWeight = 1.35 },
        { id = 'trusted', label = 'Trusted Client', loyalty = 170, priceMultiplier = 1.12, quantityMultiplier = 1.32, requestWeight = 1.65 },
        { id = 'loyal', label = 'Loyal Client', loyalty = 280, priceMultiplier = 1.18, quantityMultiplier = 1.5, requestWeight = 1.95 },
        { id = 'vip', label = 'VIP Client', loyalty = 450, priceMultiplier = 1.25, quantityMultiplier = 1.85, requestWeight = 2.35 }
    }
}

Config.Risk = {
    EnableScams = true,
    EnableRobberies = false,
    EnablePoliceAlerts = true,
    ScamGlobalChance = 2,
    RobberyGlobalChance = 0,
    InformantGlobalChance = 2
}

Config.Dispatch = {
    Provider = 'disabled',
    CustomEvent = '',
    PoliceJobs = { 'police', 'sheriff', 'state' },
    AlertChance = 12,
    AlertDelay = { min = 20, max = 65 },
    BlipRadius = 85.0,
    BlipDuration = 90,
    Message = 'Suspicious hand-to-hand activity reported',
    Code = '10-66',
    MinimumPolice = 0,
    ExposeExactCoords = false
}

Config.Notifications = {
    Provider = 'zeekota',
    CustomEvent = '',
    Position = 'top-right',
    Duration = 4800
}

Config.Audio = {
    Enabled = true,
    Volume = 0.35,
    Sounds = {
        Open = 'phone-open',
        Close = 'phone-close',
        Message = 'message',
        Click = 'click',
        Success = 'success',
        Error = 'error'
    }
}

Config.Logging = {
    Console = true,
    DiscordWebhook = '',
    IncludeIdentifiers = true,
    LogSuspiciousEvents = true
}

Config.Drugs = {
    {
        id = 'weed_bag',
        item = 'weed_bag',
        label = 'Bagged Weed',
        icon = 'leaf',
        enabled = true,
        minQuantity = 1,
        maxQuantity = 5,
        minPrice = 95,
        maxPrice = 145,
        sampleQuantity = 1,
        sampleClientChanceBonus = 18,
        sampleLoyaltyBonus = 10,
        sampleCooldown = 86400,
        extraUnitBonus = 3,
        maxExtraUnits = 3,
        reputationRequirement = 0,
        risk = 12,
        supportedArchetypes = { 'casual', 'party', 'regular', 'nervous', 'loyal' },
        weight = 35
    },
    {
        id = 'cocaine_bag',
        item = 'cocaine_bag',
        label = 'Bagged Cocaine',
        icon = 'spark',
        enabled = true,
        minQuantity = 1,
        maxQuantity = 4,
        minPrice = 240,
        maxPrice = 360,
        sampleQuantity = 1,
        sampleClientChanceBonus = 22,
        sampleLoyaltyBonus = 12,
        sampleCooldown = 86400,
        extraUnitBonus = 4,
        maxExtraUnits = 2,
        reputationRequirement = 20,
        risk = 32,
        supportedArchetypes = { 'party', 'wealthy', 'criminal', 'bulk', 'high_risk', 'loyal' },
        weight = 24
    },
    {
        id = 'meth_bag',
        item = 'meth_bag',
        label = 'Bagged Meth',
        icon = 'bolt',
        enabled = true,
        minQuantity = 1,
        maxQuantity = 6,
        minPrice = 160,
        maxPrice = 260,
        sampleQuantity = 1,
        sampleClientChanceBonus = 24,
        sampleLoyaltyBonus = 12,
        sampleCooldown = 86400,
        extraUnitBonus = 4,
        maxExtraUnits = 3,
        reputationRequirement = 15,
        risk = 38,
        supportedArchetypes = { 'regular', 'desperate', 'criminal', 'bulk', 'unreliable', 'high_risk' },
        weight = 22
    },
    {
        id = 'oxy',
        item = 'oxy',
        label = 'Oxy',
        icon = 'capsule',
        enabled = true,
        minQuantity = 2,
        maxQuantity = 8,
        minPrice = 85,
        maxPrice = 130,
        sampleQuantity = 1,
        sampleClientChanceBonus = 20,
        sampleLoyaltyBonus = 10,
        sampleCooldown = 86400,
        extraUnitBonus = 2,
        maxExtraUnits = 4,
        reputationRequirement = 10,
        risk = 24,
        supportedArchetypes = { 'regular', 'desperate', 'wealthy', 'nervous', 'loyal' },
        weight = 19
    }
}

Config.CustomerArchetypes = {
    {
        id = 'casual',
        label = 'Casual User',
        enabled = true,
        pedModels = { 'a_m_y_hipster_01', 'a_f_y_hipster_02', 'a_m_y_skater_01' },
        preferredDrugs = { 'weed_bag', 'oxy' },
        minQuantity = 1,
        maxQuantity = 4,
        budgetMultiplier = 1.0,
        loyaltyGain = 8,
        reputationRequirement = 0,
        patience = 600,
        rejectionChance = 8,
        sampleEffectiveness = 1.0,
        policeAlertChance = 3,
        robberyChance = 0,
        scamChance = 1,
        negotiationTolerance = 55,
        acquisitionModifier = 4,
        spawnAreas = {},
        timeAvailability = { start = 7, finish = 2 },
        maxRelationshipLevel = 'regular',
        repeatOrderFrequency = 1.0,
        risk = 10,
        weight = 20
    },
    {
        id = 'party',
        label = 'Party Customer',
        enabled = true,
        pedModels = { 'a_f_y_bevhills_01', 'a_m_y_bevhills_02', 'a_f_y_clubcust_02' },
        preferredDrugs = { 'cocaine_bag', 'weed_bag', 'oxy' },
        minQuantity = 2,
        maxQuantity = 7,
        budgetMultiplier = 1.18,
        loyaltyGain = 9,
        reputationRequirement = 0,
        patience = 520,
        rejectionChance = 10,
        sampleEffectiveness = 0.9,
        policeAlertChance = 8,
        robberyChance = 0,
        scamChance = 2,
        negotiationTolerance = 48,
        acquisitionModifier = 2,
        spawnAreas = {},
        timeAvailability = { start = 17, finish = 5 },
        maxRelationshipLevel = 'trusted',
        repeatOrderFrequency = 1.25,
        risk = 20,
        weight = 15
    },
    {
        id = 'regular',
        label = 'Regular Addict',
        enabled = true,
        pedModels = { 'a_m_m_tramp_01', 'a_m_o_tramp_01', 'a_f_m_tramp_01' },
        preferredDrugs = { 'meth_bag', 'oxy', 'weed_bag' },
        minQuantity = 1,
        maxQuantity = 5,
        budgetMultiplier = 0.9,
        loyaltyGain = 12,
        reputationRequirement = 0,
        patience = 720,
        rejectionChance = 7,
        sampleEffectiveness = 1.25,
        policeAlertChance = 7,
        robberyChance = 0,
        scamChance = 4,
        negotiationTolerance = 65,
        acquisitionModifier = 8,
        spawnAreas = {},
        timeAvailability = { start = 0, finish = 23 },
        maxRelationshipLevel = 'loyal',
        repeatOrderFrequency = 1.5,
        risk = 24,
        weight = 16
    },
    {
        id = 'wealthy',
        label = 'Wealthy Customer',
        enabled = true,
        pedModels = { 'a_m_y_business_02', 'a_f_y_business_01', 'a_m_m_bevhills_02' },
        preferredDrugs = { 'cocaine_bag', 'oxy' },
        minQuantity = 2,
        maxQuantity = 8,
        budgetMultiplier = 1.45,
        loyaltyGain = 10,
        reputationRequirement = 30,
        patience = 480,
        rejectionChance = 14,
        sampleEffectiveness = 0.75,
        policeAlertChance = 10,
        robberyChance = 0,
        scamChance = 2,
        negotiationTolerance = 38,
        acquisitionModifier = -2,
        spawnAreas = {},
        timeAvailability = { start = 11, finish = 3 },
        maxRelationshipLevel = 'vip',
        repeatOrderFrequency = 0.9,
        risk = 28,
        weight = 9
    },
    {
        id = 'desperate',
        label = 'Desperate Customer',
        enabled = true,
        pedModels = { 'a_m_m_skidrow_01', 'a_f_m_skidrow_01', 'a_m_y_stwhi_02' },
        preferredDrugs = { 'meth_bag', 'oxy' },
        minQuantity = 1,
        maxQuantity = 6,
        budgetMultiplier = 0.82,
        loyaltyGain = 11,
        reputationRequirement = 0,
        patience = 360,
        rejectionChance = 5,
        sampleEffectiveness = 1.35,
        policeAlertChance = 9,
        robberyChance = 0,
        scamChance = 5,
        negotiationTolerance = 70,
        acquisitionModifier = 6,
        spawnAreas = {},
        timeAvailability = { start = 0, finish = 23 },
        maxRelationshipLevel = 'regular',
        repeatOrderFrequency = 1.4,
        risk = 34,
        weight = 11
    },
    {
        id = 'nervous',
        label = 'Nervous First-Time Buyer',
        enabled = true,
        pedModels = { 'a_m_y_eastsa_01', 'a_f_y_eastsa_03', 'a_m_y_vinewood_01' },
        preferredDrugs = { 'weed_bag', 'oxy' },
        minQuantity = 1,
        maxQuantity = 3,
        budgetMultiplier = 1.05,
        loyaltyGain = 14,
        reputationRequirement = 0,
        patience = 420,
        rejectionChance = 18,
        sampleEffectiveness = 1.45,
        policeAlertChance = 14,
        robberyChance = 0,
        scamChance = 1,
        negotiationTolerance = 36,
        acquisitionModifier = 10,
        spawnAreas = {},
        timeAvailability = { start = 9, finish = 1 },
        maxRelationshipLevel = 'trusted',
        repeatOrderFrequency = 0.75,
        risk = 22,
        weight = 10
    },
    {
        id = 'criminal',
        label = 'Criminal Customer',
        enabled = true,
        pedModels = { 'g_m_y_ballaeast_01', 'g_m_y_famca_01', 'g_m_y_mexgoon_02' },
        preferredDrugs = { 'cocaine_bag', 'meth_bag', 'weed_bag' },
        minQuantity = 3,
        maxQuantity = 10,
        budgetMultiplier = 1.12,
        loyaltyGain = 9,
        reputationRequirement = 20,
        patience = 600,
        rejectionChance = 12,
        sampleEffectiveness = 0.8,
        policeAlertChance = 12,
        robberyChance = 2,
        scamChance = 3,
        negotiationTolerance = 45,
        acquisitionModifier = 0,
        spawnAreas = {},
        timeAvailability = { start = 0, finish = 23 },
        maxRelationshipLevel = 'vip',
        repeatOrderFrequency = 1.2,
        risk = 40,
        weight = 10
    },
    {
        id = 'bulk',
        label = 'Bulk Buyer',
        enabled = true,
        pedModels = { 'a_m_m_eastsa_02', 'a_m_m_soucent_04', 'g_m_m_chicold_01' },
        preferredDrugs = { 'cocaine_bag', 'meth_bag', 'weed_bag' },
        minQuantity = 5,
        maxQuantity = 14,
        budgetMultiplier = 1.0,
        loyaltyGain = 12,
        reputationRequirement = 45,
        patience = 720,
        rejectionChance = 16,
        sampleEffectiveness = 0.7,
        policeAlertChance = 16,
        robberyChance = 1,
        scamChance = 4,
        negotiationTolerance = 52,
        acquisitionModifier = -4,
        spawnAreas = {},
        timeAvailability = { start = 0, finish = 23 },
        maxRelationshipLevel = 'vip',
        repeatOrderFrequency = 0.8,
        risk = 46,
        weight = 6
    },
    {
        id = 'unreliable',
        label = 'Unreliable Customer',
        enabled = true,
        pedModels = { 'a_m_y_stbla_02', 'a_f_y_soucent_01', 'a_m_y_soucent_03' },
        preferredDrugs = { 'weed_bag', 'meth_bag', 'oxy' },
        minQuantity = 1,
        maxQuantity = 5,
        budgetMultiplier = 0.94,
        loyaltyGain = 6,
        reputationRequirement = 0,
        patience = 300,
        rejectionChance = 24,
        sampleEffectiveness = 1.0,
        policeAlertChance = 10,
        robberyChance = 0,
        scamChance = 8,
        negotiationTolerance = 72,
        acquisitionModifier = -8,
        spawnAreas = {},
        timeAvailability = { start = 0, finish = 23 },
        maxRelationshipLevel = 'regular',
        repeatOrderFrequency = 1.0,
        risk = 32,
        weight = 8
    },
    {
        id = 'high_risk',
        label = 'High-Risk Customer',
        enabled = true,
        pedModels = { 'g_m_y_salvagoon_01', 'g_m_m_armgoon_01', 'g_m_y_lost_02' },
        preferredDrugs = { 'cocaine_bag', 'meth_bag' },
        minQuantity = 2,
        maxQuantity = 9,
        budgetMultiplier = 1.2,
        loyaltyGain = 8,
        reputationRequirement = 35,
        patience = 460,
        rejectionChance = 18,
        sampleEffectiveness = 0.9,
        policeAlertChance = 24,
        robberyChance = 4,
        scamChance = 6,
        negotiationTolerance = 44,
        acquisitionModifier = -10,
        spawnAreas = {},
        timeAvailability = { start = 0, finish = 23 },
        maxRelationshipLevel = 'trusted',
        repeatOrderFrequency = 0.85,
        risk = 60,
        weight = 5
    },
    {
        id = 'loyal',
        label = 'Loyal Regular',
        enabled = true,
        pedModels = { 'a_m_m_soucent_01', 'a_f_y_soucent_02', 'a_m_y_genstreet_01' },
        preferredDrugs = { 'weed_bag', 'oxy', 'cocaine_bag' },
        minQuantity = 2,
        maxQuantity = 8,
        budgetMultiplier = 1.08,
        loyaltyGain = 14,
        reputationRequirement = 25,
        patience = 840,
        rejectionChance = 6,
        sampleEffectiveness = 1.15,
        policeAlertChance = 8,
        robberyChance = 0,
        scamChance = 1,
        negotiationTolerance = 62,
        acquisitionModifier = 10,
        spawnAreas = {},
        timeAvailability = { start = 0, finish = 23 },
        maxRelationshipLevel = 'vip',
        repeatOrderFrequency = 1.65,
        risk = 18,
        weight = 7
    },
    {
        id = 'informant',
        label = 'Informant Risk Customer',
        enabled = true,
        pedModels = { 'a_m_m_business_01', 'a_f_y_business_04', 'a_m_y_genstreet_02' },
        preferredDrugs = { 'cocaine_bag', 'meth_bag', 'oxy' },
        minQuantity = 1,
        maxQuantity = 5,
        budgetMultiplier = 1.1,
        loyaltyGain = 5,
        reputationRequirement = 15,
        patience = 520,
        rejectionChance = 14,
        sampleEffectiveness = 0.8,
        policeAlertChance = 35,
        robberyChance = 0,
        scamChance = 4,
        negotiationTolerance = 35,
        acquisitionModifier = -12,
        spawnAreas = {},
        timeAvailability = { start = 0, finish = 23 },
        maxRelationshipLevel = 'returning',
        repeatOrderFrequency = 0.6,
        risk = 72,
        weight = 4
    }
}

Config.MessageTemplates = {
    NewCustomer = {
        'You active right now?',
        'A friend said you were reliable.',
        'Looking for a few. Do not waste my time.',
        'You got anything stronger?',
        'Can you meet near me?',
        'I am not trying to wait all night.',
        'Someone gave me your Backpage name.',
        'You still serving this side of town?'
    },
    ExistingClient = {
        'Need {drug} quick. Same energy as last time?',
        'Need my usual {drug}.',
        'You around tonight? I need {drug}.',
        'You still good for {drug}?',
        'Can you meet near me again? I need {drug}.',
        'Last time was clean. I need more {drug}.'
    },
    Accepted = {
        'I can meet you. I will send a nearby spot.',
        'Pull up and keep it quiet.',
        'I marked a place. Do not bring attention.'
    },
    Declined = {
        'Not tonight.',
        'I cannot do that one.',
        'Find someone else for this.'
    },
    Completed = {
        'Good business.',
        'Clean. I will keep your contact.',
        'That worked. I may hit you again.'
    },
    Sample = {
        'Sample provided.',
        'Try this first.',
        'No charge on this one.'
    },
    OfferAccepted = {
        'Fine. Bring that instead, but the number changes.',
        'I can work with that, but not for the same price.',
        'That works. Keep it quick.'
    },
    OfferRejected = {
        'No. I asked for something specific.',
        'That is not what I need.',
        'Do not switch it up on me.'
    },
    Failed = {
        'You took too long.',
        'This is dead.',
        'Forget it.'
    }
}

Config.ProfileAvatars = {
    'ZK', 'AX', 'K9', 'NO', 'RX', 'L7', 'DM', 'QZ', 'SV', 'MT', 'JR', 'NX'
}

Config.CustomerAliases = {
    'Blue Static', 'Nightline', 'Quiet Rook', 'Low Battery', 'Southside Echo',
    'No Caller ID', 'Glass Table', 'Side Door', 'Metro Ghost', 'Lucky Seven',
    'Last Stop', 'Late Fee', 'Page Nine', 'Cornerlight', 'Cash Only',
    'Rain Check', 'Old Pager', 'Back Seat', 'Half Moon', 'Cold Signal'
}
