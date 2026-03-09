type SortOrder = 'asc' | 'desc';

export function parseListQuery(
  query: Record<string, unknown>,
  defaults: { limit?: number; sortBy: string; sortOrder?: SortOrder },
  allowedSortBy: string[]
): { offset: number; take: number; sortBy: string; sortOrder: SortOrder } {
  const offsetRaw = typeof query.offset === 'string' && query.offset.trim() ? Number(query.offset.trim()) : 0;
  const limitRaw =
    typeof query.limit === 'string' && query.limit.trim() ? Number(query.limit.trim()) : (defaults.limit ?? 50);
  const sortByRaw =
    typeof query.sortBy === 'string' && query.sortBy.trim() ? query.sortBy.trim() : defaults.sortBy;
  const sortOrderRaw =
    typeof query.sortOrder === 'string' && query.sortOrder.trim() ? query.sortOrder.trim() : (defaults.sortOrder ?? 'asc');

  return {
    offset: Number.isFinite(offsetRaw) ? Math.max(Math.trunc(offsetRaw), 0) : 0,
    take: Number.isFinite(limitRaw) ? Math.min(Math.max(Math.trunc(limitRaw), 1), 100) : defaults.limit ?? 50,
    sortBy: allowedSortBy.includes(sortByRaw) ? sortByRaw : defaults.sortBy,
    sortOrder: sortOrderRaw === 'desc' ? 'desc' : 'asc'
  };
}

function compareValues(left: unknown, right: unknown) {
  if (typeof left === 'number' && typeof right === 'number') return left - right;
  if (left instanceof Date && right instanceof Date) return left.getTime() - right.getTime();
  return String(left ?? '').localeCompare(String(right ?? ''));
}

export function sortAndPaginate<T extends Record<string, any>>(
  items: T[],
  query: { offset: number; take: number; sortBy: string; sortOrder: SortOrder }
) {
  const direction = query.sortOrder === 'desc' ? -1 : 1;
  const sorted = [...items].sort((left, right) => {
    const primary = compareValues(left[query.sortBy], right[query.sortBy]) * direction;
    if (primary !== 0) return primary;
    return compareValues(left.createdAt, right.createdAt) * direction;
  });
  const paged = sorted.slice(query.offset, query.offset + query.take);

  return {
    items: paged,
    meta: {
      limit: query.take,
      offset: query.offset,
      returned: paged.length,
      total: sorted.length,
      hasMore: query.offset + paged.length < sorted.length,
      sortBy: query.sortBy,
      sortOrder: query.sortOrder
    }
  };
}
