// Relevant snippets from the API.ts file from the front-end application.

import axiosInstance from './axiosInstance';
import * as FileSystem from 'expo-file-system';
// --- Import filter types from store ---
import { LocationFilter, DateRangeFilter, DateType } from '../stores/searchFilterStore';
import { formatISO, startOfDay, endOfDay, addDays, subDays, startOfWeek, endOfWeek } from 'date-fns'; // For date calculations
import * as geolib from 'geolib'; // Import geolib for geospatial calculations

export interface LoginCredentials {
  email: string;
  password: string;
  'include-in-response': boolean; // For mobile clients
  'remember-me': boolean; // For extended login period
}

export interface LoginResponse {
  access_token: string;
  refresh_token?: string; // When include-in-response is true
}

export interface CreateAccountCredentials {
  email: string;
  password: string;
}
export interface CreateAccountResponse {
  data: {
    id: string;
    email: string;
  }
}

export interface Category {
  id: string;
  attributes: {
    name: string;
    // Add other potential category attributes if needed
  };
}

export interface Event {
  id: string;
  attributes: {
    name: string;
    'starts-at': string;
    'address': string; // 'location-name' on the backend
    'searchable-location-name': string;
    'logo-url': string;
    identifier?: string;
    description: string;
    'owner-name': string;
    'ends-at': string;  // Add ends-at
    latitude?: string; // Add latitude as optional string
    longitude?: string; // Add longitude as optional string
    'is-featured'?: boolean;
    state: string;
    'onsite-details'?: string; // This will store our recurrence rule JSON
  };
  'category-id'?: string; // json-api event-topic relationship on backend
  'intended-ages'?: IntendedAge[]; // json-api session-types then session-type.attributes.title on the backend
  'cost'?: 'free' | 'paid'; // json-api tickets then ticket.attributes.type on the backend
  'recurrence-rule'?: string; // Changed to string for iCalendar RRULE
}




export interface User {
  data: {
    attributes: {
      "first-name": string;
      "last-name": string;
      "avatar-url": string | null;
      email: string;
      details?: string;
      contact?: string | null;
      "facebook-url"?: string | null;
      "twitter-url"?: string | null;
      "instagram-url"?: string | null;
      "google-plus-url"?: string | null;
    };
    id: string;
  }
}

export interface UpdateUserData {
  "first-name": string;
  "last-name": string;
  "avatar-url"?: string | null;
  details?: string;
  contact?: string | null;
  "facebook-url"?: string | null;
  "twitter-url"?: string | null;
  "instagram-url"?: string | null;
  "google-plus-url"?: string | null;
}




export const eventApi = {
  createEvent: async (eventData: Event): Promise<Event> => {
    // Get the user's timezone
    const userTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;

    // Extract the special fields we'll handle separately
    const intendedAges = eventData['intended-ages'];
    const categoryId = eventData['category-id'];
    const cost = eventData['cost'];

    // Filter out null/empty values from attributes
    const filteredAttributes: Record<string, any> = {};
    for (const [key, value] of Object.entries(eventData.attributes)) {
      if (value !== null && value !== '') {
        filteredAttributes[key] = value;
      }
    }

    const eventPayload: any = {
      data: {
        attributes: {
          ...filteredAttributes,
          'is-featured': undefined,
          'location-name': eventData.attributes.address,
          'address': undefined,
          'timezone': userTimezone, // Add the user's timezone
          'can-pay-by-cheque': cost === 'paid' ? true : undefined
        },
        type: 'event',
        relationships: {}
      }
    };

    // Add recurrence-rule to onsite-details
    if (eventData['recurrence-rule']) {
      eventPayload.data.attributes['onsite-details'] = eventData['recurrence-rule'];
    }
    // Add event-topic relationship if categoryId exists
    if (categoryId) {
      eventPayload.data.relationships['event-topic'] = {
        data: {
          type: "event-topic",
          id: categoryId
        }
      };
    }

    // Create the event
    const eventResponse = await axiosInstance.post('/v1/events', eventPayload);

    console.log("Response from createEvent: ");
    // console.log(JSON.stringify(eventResponse.data));

    const createdEvent = eventResponse.data.data;
    const eventId = createdEvent.id;

    // Create session-types for intended-ages if they exist
    if (intendedAges && intendedAges.length > 0) {
      for (const age of intendedAges) {
        await axiosInstance.post('/v1/session-types', {
          data: {
            relationships: {
              event: {
                data: {
                  type: "event",
                  id: eventId
                }
              }
            },
            attributes: {
              name: age,
              length: "00:30" // Default length
            },
            type: "session-type"
          }
        });
      }
    }

    // Create ticket for cost if it exists
    if (cost) {
      await axiosInstance.post('/v1/tickets', {
        data: {
          relationships: {
            event: {
              data: {
                type: "event",
                id: eventId
              }
            }
          },
          attributes: {
            name: "General Admission",
            type: cost, // 'free' or 'paid'
            price: cost === 'free' ? 0 : 10, // Placeholder price
            quantity: 100, // Placeholder quantity
            'min-order': 1,
            'sales-starts-at': '1970-01-01T00:00:00Z', // Using start of epoch to fix time out of order bug
            'sales-ends-at': eventData.attributes['ends-at'], // Use event end time as ticket sales end time
          },
          type: "ticket"
        }
      });
    }

    // Fetch the created event with all relationships
    return await eventApi.getEventById(eventId);
  },

  getEventById: async (eventId: string): Promise<Event> => {
    const response = await axiosInstance.get(`/v1/events/${eventId}?include=event-topic,session-types,tickets`);

    const eventData = response.data.data;
    const included = response.data.included || [];

    // Initialize the Event object with the basic data
    const event: Event = {
      id: eventData.id,
      attributes: {
        ...eventData.attributes,
        // Map location-name to address if it exists
        'address': eventData.attributes['location-name'] || '',
      },
    };

    // Extract category-id from event-topic relationship
    if (eventData.relationships?.["event-topic"]?.data) {
      event["category-id"] = eventData.relationships["event-topic"].data.id;
    }

    // Extract intended-ages from session-types
    if (eventData.relationships?.["session-types"]?.data) {
      const sessionTypeIds = eventData.relationships["session-types"].data.map(
        (item: any) => item.id
      );

      const sessionTypes = included.filter(
        (item: any) => item.type === "session-type" && sessionTypeIds.includes(item.id)
      );

      // Type guard to check if a string is a valid IntendedAge
      const isValidIntendedAge = (value: string): value is IntendedAge => {
        return AllIntendedAges.includes(value);
      };

      event["intended-ages"] = sessionTypes
        .map((st: any) => st.attributes.name)
        .filter(isValidIntendedAge);
    }

    // Extract cost from tickets
    if (eventData.relationships?.["tickets"]?.data?.length > 0) {
      const ticketIds = eventData.relationships["tickets"].data.map(
        (item: any) => item.id
      );

      const tickets = included.filter(
        (item: any) => item.type === "ticket" && ticketIds.includes(item.id)
      );

      if (tickets.length > 0) {
        event["cost"] = tickets[0].attributes.type as 'free' | 'paid';
      }
    }

    // Prioritize 'onsite-details' for recurrence rule
    if (eventData.attributes['onsite-details']) {
      event['recurrence-rule'] = eventData.attributes['onsite-details'];
    }

    console.log("Parsed event:", event);
    return event;
  },
  deleteEvent: async (eventId: string): Promise<void> => {
    try {
      // 1. Get all tickets for this event
      const ticketsResponse = await axiosInstance.get(`/v1/events/${eventId}/tickets`);
      const tickets = ticketsResponse.data.data || [];
      
      // 2. Get all session types for this event
      const sessionTypesResponse = await axiosInstance.get(`/v1/events/${eventId}/session-types`);
      const sessionTypes = sessionTypesResponse.data.data || [];
      
      // 3. Delete all tickets
      for (const ticket of tickets) {
        await axiosInstance.delete(`/v1/tickets/${ticket.id}`);
      }

      // 4. Delete all session types
      for (const sessionType of sessionTypes) {
        await axiosInstance.delete(`/v1/session-types/${sessionType.id}`);
      }

      // 5. Finally delete the event
      await axiosInstance.delete(`/v1/events/${eventId}`);
    } catch (error) {
      console.error("Error deleting event and its related resources:", error);
      throw error;
    }
  },

};

