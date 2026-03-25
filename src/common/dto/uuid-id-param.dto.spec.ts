import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

import { UuidIdParamDto } from './uuid-id-param.dto';

describe('UuidIdParamDto', () => {
  it('accepts seeded demo ids that are uuid-shaped but not v4', async () => {
    const dto = plainToInstance(UuidIdParamDto, {
      id: '60000000-0000-0000-0000-000000000003',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('accepts standard v4 ids', async () => {
    const dto = plainToInstance(UuidIdParamDto, {
      id: '3f2504e0-4f89-41d3-9a0c-0305e82c3301',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('still rejects non-uuid ids', async () => {
    const dto = plainToInstance(UuidIdParamDto, {
      id: 'question-1',
    });

    const errors = await validate(dto);

    expect(errors).not.toHaveLength(0);
  });
});
